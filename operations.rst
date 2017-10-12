##########
Operations
##########

.. _basic_io:

Basic I/O
=========

To see how the various components interact we first examine a basic ``get`` and ``put`` operations for the basic case of a non-composite :ref:`Dataset`.
We assume that the :ref:`Butler` is configured with an external :ref:`Registry` and :ref:`Datastore`, both consisting of a client-server pair.

Basic ``get``
-------------

The user has a :py:class:`DatasetLabel`, constructed or obtained by a query and wishes to retrieve the associated :ref:`InMemoryDataset`.

This proceeds allong the following steps:

1. User calls: ``butler.get(label)``.
2. :ref:`Butler` forwards this call to its :ref:`Registry`, adding the :ref:`CollectionTag <Collection>` it was configured with (i.e. ``butler.registry.find(butler.config.inputCollection, label)``).
3. :ref:`Registry` performs the lookup on the server using SQL and returns the :ref:`URI` for the stored :ref:`Dataset` (via a :py:class:`DatasetHandle`)
4. :ref:`Butler` forwards the request, with both the :ref:`URI` and the :ref:`StorageClass`, to the :ref:`Datastore` client (i.e. ``butler.datastore.get(handle.uri, handle.type.storageClass)``).
5. :ref:`Datastore` client requests a serialized version of the :ref:`Dataset` from the server using the :ref:`URI`.
6. Using the :ref:`StorageClass` to determine the appropriate deserialization function, the :ref:`Datastore` client then materializes the :ref:`InMemoryDataset` and returns it to the :ref:`Butler`.
7. :ref:`Butler` then returns the :ref:`InMemoryDataset` to the user.

See :py:meth:`the API documentation <Butler.get>` for more information.

.. note::

    * The :ref:`Datastore` request can be a simple ``HTTP GET`` request for a stored FITS file, or something more complicated.
      In the former case the materialization would be a simple FITS read (e.g. of a ``calexp``), with the reader determined by the :ref:`StorageClass` retrieved from the :ref:`Registry`.

    * The serialized version sent over the wire doesn't have to correspond to the format stored on disk in the :ref:`Datastore` server.  It just needs to be serialized in the form expected by the client.

Basic ``put``
-------------

The user has a :ref:`InMemoryDataset` and wishes to store this at a particular :py:class:`DatasetLabel`.

This proceeds allong the following steps:

1. User calls: ``butler.put(label, inMemoryDataset)``.
2. :ref:`Butler` expands the :py:class:`DatasetLabel` into a full :py:class:`DatasetRef` using the :ref:`Registry`, by calling ``datasetRef = butler.registry.expand(label)``.
3. :ref:`Butler` obtains a :ref:`Path` by calling ``path = datasetRef.makePath(butler.config.outputCollection, template)``. This path is a hint to be used by the :ref:`Datastore` to decide where to store it.  The template is provided by the :ref:`Registry` but may be overridden by the :ref:`Butler`.
4. :ref:`Butler` then asks the :ref:`Datastore` client to store the file by calling: ``butler.datastore.put(inMemoryDataset, datasetRef.type.storageClass, path, datasetRef.type.name)``.
5. The :ref:`Datastore` client then uses the serialization function associated with the :ref:`StorageClass` to serialize the :ref:`InMemoryDataset` and sends it to the :ref:`Datastore` server.
   Depending on the type of server it may get back the actual :ref:`URI` or the client can generate it itself.
6. :ref:`Datastore` returns the actual :ref:`URI` to the :ref:`Butler`.
7. :ref:`Butler` calls the :ref:`Registry` function ``addDataset`` to add the :ref:`Dataset`.
8. :ref:`Butler` returns a :py:class:`DatasetHandle` to the user.

See :py:class:`the API documentation <Butler.put>` for more information.

.. _composites:

Composites
==========

A :ref:`Dataset` can be **composite**, in which case it consists of a **parent** :ref:`Dataset` and one or more child :ref:`Datasets <Dataset>`.  An example would be an ``Exposure`` which includes a ``Wcs``, a ``Mask``, and an ``Image`` (as well as other components).  There are several ways this may be stored by the :ref:`Datastore`:

* As part of the parent :ref:`Dataset` (e.g. the full ``Exposure`` is written to a single FITS file).
* As a set of entities without a parent (e.g. only the ``Wcs``, ``Mask`` and ``Image`` are written separately and the ``Exposure`` needs to be composed from them).
* As a mix of the two extremes (e.g. the ``Mask`` and ``Image`` are part of the ``Exposure`` file but the ``Wcs`` is written to a separate file).

In either case the user expects to be able to read an individual component, and in case the components are stored separately the transfer should be efficient.

In addition, it is desirable to be able to **override** parts of a composite :ref:`Dataset` (e.g. updated metadata), by defining a new :ref:`DatasetType` that mixes components from the original :ref:`Dataset` with new ones.

To support this the :ref:`Registry` is also responsible for storing the component :ref:`Datasets <Dataset>` of the **composite**.

The :py:class:`DatasetHandle` returned by :py:meth:`Registry.find` therefore not only includes the :ref:`URI` and :ref:`StorageClass` of the **parent** (associated with the :ref:`DatasetRef`), but also a ``components`` dictionary of ``name : DatasetHandle`` specifying its **children**.

The :ref:`Butler` retrieves **all** :ref:`Datasets <Dataset>` from the :ref:`Datastore` as :ref:`InMemoryDatasets <InMemoryDataset>` and then calls the ``assemble`` function associated with the :ref:`StorageClass` of the primary to create the final composed :ref:`InMemoryDataset`.

This process is most easily understood by reading the API documentation for :py:meth:`butler.get <Butler.get>` and :py:meth:`butler.put <Butler.put>`.

.. _transferring_registries_and_datastores:

Transferring Registries and Datastores
======================================

A user has a :ref:`Butler` instance that holds a :ref:`Registry` client instance and a :ref:`Datastore` client instance, both connected to their remote server equivalents. Now the user wants to obtain a local subset of the upstream :ref:`Datasets <Dataset>` (and all related :ref:`DataUnits <DataUnit>`, :ref:`DatasetTypes <DatasetType>` and possibly :ref:`Quanta <Quantum>` and :ref:`Collections <Collection>`) held by the :ref:`Registry`.

There are three cases:

* transfer a subset of the :ref:`Registry`, but not the actual :ref:`Datasets <Dataset>` held by the :ref:`Datastore`, or
* transfer both a subset of the :ref:`Registry` and the :ref:`Datasets <Dataset>` themselves, or
* *transfer only the* :ref:`Datasets <Dataset>` *from the* :ref:`Datastore` *but keep the remote* :ref:`Registry`.

We will ignore the last one for now, because it is effectively a kind of caching, and focus on the first two instead.

While no high-level API for transfers exists in the current design, it is relatively easy to implement on top of the provided low-level API.

.. py:function:: transfer(dst, src, expr, tag, copyDatasets=False)

    Transfer :ref:`Datasets <Dataset>` and related entities between :ref:`Butlers <Butler>`.

    :param Butler dst: :ref:`Butler` instance of destination.
    :param Butler src: :ref:`Butler` instance of source.
    :param str expr: an expression (SQL query that evaluates to a list of dataset_id) that selects the Datasets.
    :param str tag: a CollectionTag used to identify the requested transfered :ref:`Datasets <Dataset>` in the :ref:`Registry` of the destination :ref:`Butler`.
    :param bool copyDatasets: Should the :ref:`Datasets <Dataset>` be copied from the source to the destination :ref:`Datastore`?

    A possible implementation could be:

    .. code:: python
    
        dst.registry.transfer(src.registry, expr, tag)

        if copyDatasets:
            for label in dst.query(
                # get DatasetLabels for all Datasets in tag
                ):

                ref = dst.registry.expand(label)
                template = dst.config.templates.get(ref.type.name, None)
                path = ref.makePath(dst.config.outputCollection, template)
                handle = src.registry.find(tag, label)

                uri, components = dst.datastore.transfer(src.datastore, handle.uri, ref.type.storageClass, path, ref.type.name)
                dst.registry.addDataset(ref, uri, components, handle.producer, handle.run)
        else:
            # The following assumes the old datastore was empty and that the datastore will be
            # read-only.  Otherwise we will have to some chaining.
            dst.datastore = src.datastore


    .. todo::

        This is just a draft implementation to show the interfaces enable ``transfer`` to be written.
        However there are many remaining details to be worked out. Such as:

            * What should happen if the :ref:`Dataset` composition is different in the output datastore?
            * How exactly to implement :ref:`Datastore` chaining?
            * How to make this transactionally safe?
            * At what place in the component hierarchy should the high-level transfer be implemented?
              Since it is effectively a double-dispatch problem.

        Once these details have been worked out the high-level transfer should become part of the API.

    .. note::

        Depending on the ability to join user tables to data release tables in the science platform,
        transfers between butlers may or may not be common.


Remote Access and Caching
=========================

The user has a :ref:`Butler` instance. This :ref:`Butler` instance holds a local :ref:`Registry` client instance that is connected to a remote **read-only** :ref:`Registry` server (database). It also holds a local :ref:`Datastore` client that also is connected to a remote :ref:`Datastore`.

The user now calls ``butler.get()`` to obtain an :ref:`InMemoryDataset` from the :ref:`Datastore`, proceeds with some further processing, and subsequently wants to load the **same** :ref:`InMemoryDataset` again.

This is most easily supported by a pass-through **caching** :ref:`Datastore`. The :ref:`Butler` now holds an instance of the caching :ref:`Datastore` instead. The caching :ref:`Datastore` in turn holds the client to the remote :ref:`Datastore`.

.. digraph:: ButlerWithDatastoreCache
    :align: center

    node[shape=record]
    edge[dir=back, arrowtail=empty]

    Butler -> ButlerConfiguration [arrowtail=odiamond];
    Butler -> DatastoreCache [arrowtail=odiamond];
    DatastoreCache -> Datastore [arrowtail=odiamond];
    Butler -> Registry [arrowtail=odiamond];

A trivial implementation, for a non-persistent cache, could be:

.. py:class:: DatastoreCache

    .. py:attribute:: cache

        A dictionary of ``{(URI, parameters) : InMemoryDataset}``.

    .. py:attribute:: datastore

        The chained :ref:`Datastore`.

    .. py:method:: __init__(datastore)

        Initialize with chained :ref:`Datastore`.

    .. py:method:: get(uri, parameters=None)

        Implemented as:

        .. code:: python

            def get(uri, parameters=None):
                if (uri, parameters) not in self.cache:
                    self.cache[(uri, parameters)] = self.datastore.get(uri, parameters)

                return self.cache[(uri, parameters)]

    .. py:method:: put(inMemoryDataset, storageClass, path, typeName=None) -> URI, {name: URI}

        Direct forward to ``self.datastore.put``.

    .. py:method:: transfer(inputDatastore, inputUri, storageClass, path, typeName=None) -> URI, {name: URI}

        Direct forward to ``self.datastore.transfer``.

.. todo::

    * What to do when ``parameters`` differ? Should we re-slice?

    * Work out how persistable caches should be implemented.

.. note::

    Caching is fundamentally different from :ref:`transferring_registries_and_datastores` in that it does not modify the :ref:`Registry` at all.  This makes it a much more lightweight operation when the input :ref:`Registry` is read-only (and only read-only access is needed), but it means the :ref:`Registry` cannot be used to obtain the local path to the cached files for use by external tools.

SuperTask Pre-Flight and Execution
==================================

.. note::

    This description currently has the SuperTask *control code* operating directly on :ref:`Registry` and :ref:`Datastore` objects instead of :ref:`Butlers <Butler>`.
    Actual SuperTasks, of course, still only see a :ref:`Butler`.
    But we should decide when the design is more mature whether to hide the interfaces the control code uses behind :ref:`Butler` as well.

Preflight
---------

The inputs to SuperTask preflight are considered here to be:

 - an input :ref:`Registry` instance (may be read-only)
 - an input :ref:`Datastore` instance (may be read-only)
 - an output :ref:`Registry` instance (may be the same as the input :ref:`Registry`, but must not be read-only)
 - an output :ref:`Datastore` instance (may be the same as the input :ref:`Datastore`, but must not be read-only)
 - a Pipeline (contains SuperTasks, configuration, and the set of :ref:`DatasetTypes <DatasetType>` needed as inputs and expected as outputs)
 - a user expression that limits the :ref:`DataUnits <DataUnit>` to process.
 - an ordered list of :ref:`CollectionTags <Collection>` from which to obtain inputs
 - a :ref:`CollectionTag <Collection>` that labels the processing run.

.. todo::

    In order to construct the SuperTasks in a Pipeline (and extract the :ref:`DatasetTypes <DatasetType>`), we need to pass the SuperTask constructors a :ref:`Butler` or some other way to load the schemas of any catalogs they will use as input datasets.  These may differ between collections!

#. Preflight begins with the activator calling :py:class:`Registry.makeDataGraph` with the given expression, list of input tags, and the sets of :ref:`DatasetTypes <DatasetType>` implicit in the Pipeline.  The returned :ref:`QuantumGraph` contains both the full set of input :ref:`Datasets <Dataset>` that may be required and the full set of :ref:`DataUnits <DataUnit>` that will be used to describe any future :ref:`Datasets <Dataset>`.

#. If the output :ref:`Registry` is not the same as the input :ref:`Registry`, the activator transfers (see :ref:`transferring_registries_and_datastores`) all :ref:`Registry` content associated with the :ref:`Datasets <Dataset>` in the graph to the output :ref:`Registry`.  The input :ref:`Datasets <Dataset>` themselves *may* be transferred to the output :ref:`Datastore` at the same time if this will make subsequent processing more efficient.

#. The activator calls :py:meth:`Registry.makeRun` on the output :ref:`Registry` with the output :ref:`CollectionTag <Collection>`, obtaining a :py:class:`Run` instance.

#. The activator adds all input :ref:`Datasets <Dataset>` to the :ref:`Run's <Run>` :ref:`Collection` (in the :ref:`Registry`; this does not affect the :ref:`Datastore` at all).  Note that from this point forward, we need only work with a single :ref:`Collection`, as we have aggregated everything relevant from the multiple input :ref:`Collections <Collection>` into a single input/output :ref:`Collection`.

#. The activator constructs a :ref:`Butler` from the output :ref:`Registry` (which can now also be used as input), the :ref:`Run's <Run>` :ref:`Collection`, and either the given :ref:`Datastore` (if the same one is used for input and output) or a pass-through :ref:`Datastore` that forwards input and output requests to the two given ones appropriately.

#. The activator records the Pipeline configuration and a description of the software environment (as regular :ref:`Datasets <Dataset>`) using the :ref:`Butler` and associates them with the :ref:`Run` by calling :py:meth:`Registry.updateRun`.

#. The activator calls ``defineQuanta`` on each of the SuperTasks in the Pipeline, passing them the :ref:`Run` and the :ref:`QuantumGraph`.  Each SuperTask manipulates the :ref:`QuantumGraph` to add its :ref:`Quanta <Quantum>` and output :ref:`DatasetRef <DatasetRef>` to it.

    .. note::

        This differs slightly from the SuperTask design in DMTN-055, in which SuperTasks return unstructured lists of Quanta and the activator assembles them into a graph.

After these steps, the :ref:`QuantumGraph` contains a complete description of the processing to be run, with each :ref:`Quantum` it holds having complete :py:attr:`predictedInputs <Quantum.predictedInputs>` and :py:attr:`outputs <Quantum.outputs>` lists.
The :ref:`QuantumGraph` can then be serialized or otherwise transferred to a workflow system to schedule execution.

At the end of preflight, the only modifications that have been made to the output :ref:`Registry` are the addition of a :ref:`Run`, the association of all input :ref:`Datasets <Dataset>` with the :ref:`Run's <Run>` :ref:`Collection`, and the addition of :ref:`Datasets <Dataset>` recording the configuration and software environment.  Those two :ref:`Datasets <Dataset>` are the only modifications to the output :ref:`Datastore`.

.. todo::

    May want to try a few examples of ``defineQuanta`` implementations, perhaps covering applying master calibrations and making coadds.

.. _building_preflight_queries:

Building Preflight Queries
^^^^^^^^^^^^^^^^^^^^^^^^^^

The call to :py:meth:`Registry.makeDataGraph` at the start of Preflight hides a great deal of complexity that is central to how the :ref:`Registry` schema supports SuperTask Preflight.
The implementation of :py:meth:`makeDataGraph <Registry.makeDataGraph>` is responsible for generating a complex SQL query, interpreting the results, and packaging them into a data structure (a :py:class:`QuantumGraph` with a :py:class:`DataUnitMap`) that can be queried and extended by ``SuperTask.defineQuanta``.

The query generated by :py:meth:`Registry.makeDataGraph` is built by combining a machine-generated output field clause, a machine generated ``FROM`` clause, a machine-generated partial ``WHERE`` clause, and a supplemental partial ``WHERE`` clause provided by the user (the "expression" discribed above).

As an example, we'll consider the case where we are building coadds, which means we're combining ``warp`` :ref:`Datasets <Dataset>` to build ``coadd`` :ref:`Datasets <Dataset>`.
The :ref:`DataUnit` types associated with ``warp`` are:

 - :ref:`Visit`
 - :ref:`PhysicalFilter`
 - :ref:`Camera`
 - :ref:`Patch`
 - :ref:`Tract`
 - :ref:`SkyMap`

 while those associated with ``coadd`` are:

 - :ref:`Patch`
 - :ref:`Tract`
 - :ref:`SkyMap`
 - :ref:`AbstractFilter`

It's worth noting that of these, only :ref:`Visit` and :ref:`Patch` are needed to fully identify a ``warp`` and only :ref:`Patch` and :ref:`AbstractFilter` are needed to identify a ``coadd``; all of the other :ref:`DataUnit` types are uniquely identifed as foreign key targets of these.

Because the Pipeline we're running starts with ``warps`` produced in another processing run, ``warp`` will be the only element in the ``neededDatasetTypes`` argument and ``coadd`` will be the only element in the ``futureDatasetTypes`` argument.

The process starts by extracting the :ref:`DataUnit` types from both the ``neededDatasetTypes`` and ``futureDatasetTypes`` arguments to :py:meth:`makeDataGraph <Registry.makeDataGraph>`, and removing duplicates.
Python code to do that looks something like this:

.. code:: python

    unitTypes = []
    for datasetType in neededDatasetTypes:
        unitTypes.extend(datasetType.units)
    for datasetType in futureDatasetTypes:
        unitTypes.extend(datasetType.units)
    unitTypes = DataUnitTypeSet(unitTypes)  # removes duplicates

In our coaddition example, ``unitTypes == (Visit, PhysicalFilter, Camera, Patch, Tract, SkyMap, AbstractFilter)``.

We add the tables for all of these :ref:`DataUnit` types to the ``FROM`` clause, with inner joins between all of them, and add their "value" fields to the field list.
Our example query now looks like this:

.. code:: sql

    SELECT
        Visit.visit_number,
        PhysicalFilter.physical_filter_name,
        Camera.camera_name,
        Patch.patch_index,
        Tract.tract_number,
        SkyMap.skymap_name,
        AbstractFilter.abstract_filter_name
    FROM
        Visit
        INNER JOIN PhysicalFilter
        INNER JOIN Camera
        INNER JOIN Patch
        INNER JOIN Tract
        INNER JOIN SkyMap
        INNER JOIN AbstractFilter


We'll add the join restrictions later as part of the ``WHERE`` clause instead of via ``ON`` clauses.
Using ``ON`` is certainly possible and may be advisable in an actual implementation, but it makes the logic a bit harder to follow.

Some of the join restrictions are simple; they're just the foreign keys in the tables we've included.
The remaining join restrictions between the :ref:`DataUnits <DataUnit>` involve bringing the :ref:`many-to-many join tables <dataunit_joins>` between :ref:`DataUnits <DataUnit>`.
We simply include any join table that corresponds to any pair of :ref:`DataUnit` types in the full list.
That appends the following to our SQL statement:

.. code:: sql

    % ...everything in the past SQL code snippet...
        INNER JOIN VisitPatchJoin
    WHERE
        Visit.physical_filter_name = PhysicalFilter.physical_filter_name
            AND
        Visit.camera_name = Camera.camera_name
            AND
        PhysicalFilter.camera_name = Camera.camera_name
            AND
        Patch.tract_number = Tract.tract_number
            AND
        Patch.skymap_name = SkyMap.skymap_name
            AND
        Tract.skymap_name = SkyMap.skymap_name
            AND
        PhysicalFilter.abstract_filter_name = AbstractFilter.abstract_filter_name
            AND
        VisitPatchJoin.visit_number = Visit.visit_number
            AND
        VisitPatchJoin.camera_name = Visit.camera_name
            AND
        VisitPatchJoin.patch_index = Patch.patch_index
            AND
        VisitPatchJoin.tract_number = Patch.tract_number
            AND
        VisitPatchJoin.skymap_name = Patch.skymap_name

.. todo::

    That last statement in the text is a small lie; we don't want to bring in the VisitTractJoin table even though both Visit and Tract are in our list because it's redundant with VisitPatchJoin.
    That's not hard to fix; we just need to invent a rule that says to never include some join table if you already have another one, and define that hierarchy in the concrete DataUnit reference sections.

This query already produces the table of :ref:`DataUnit` primary key values we'd need to construct a :py:class:`DataUnitMap`, which is one of the most important components of the :py:class:`QuantumGraph` we'll pass to ``SuperTask.defineQuanta``.
But it currently covers the full "universe" of possible coadds: any known :ref:`Visit` that overlaps any known :ref:`Patch` is included.
We want to filter this in two ways:

 - we need to apply the user's filter expression;
 - we need to only consider ``warps`` that already exist in the :ref:`Collection(s) <Collection>` we're using as inputs.

We'll start with the first one, because it's easy: we just append the user expression to the end of the ``WHERE`` clause with an extra ``AND``, wrapping it in parenthesis.
That provides a very straightforward definition of what the user expression is: any valid SQL boolean expression that utilizes any of the :ref:`DataUnit` tables implied by the Pipeline.
Some examples:

 - Make coadds for any patches and filters that involve a range of HSC visits:

    .. code:: sql

        (Visit.visit_number BETWEEN 500 AND 700)
            AND
        Camera.camera_name = 'HSC'
            AND
        SkyMap.skymap_name = 'SSP-WIDE

 - Make a *r*-band coadd for a specific patch and filter, using any available data from HSC and CFHT:

    .. code:: sql

        Tract.tract_number = 23
            AND
        Patch.patch_index = 56
            AND
        SkyMap.skymap_name = 'SSP-WIDE`
            AND
        AbstractFilterName.abstract_filter_name = 'r'
            AND
        (Camera.camera_name = 'HSC' OR Camera.camera_name = 'CFHT')

 - Make all coadds with data taken after a certain date:

    .. code:: sql

        Visit.obs_begin > '2017-10-14'
            AND
        Camera.camera_name = 'HSC'
            AND
        SkyMap.skymap_name = 'SSP-WIDE


A few things stand out:

 - It's almost always necessary to provide both the camera name and the skymap name.  We could imagine having the higher-level activator code provide defaults for these so the user doesn't always have to include them explicitly.

 - The expressions can get quite verbose, as there's a lot of redundancy between the table names and the field names.  We might be able to eliminate a lot of that via a regular expression or other string substitution that transforms any comparison on a :ref:`DataUnit` type (e.g. ``Visit = 500``) name to a comparison on its "value" field (e.g. ``Visit.visit_number = 500``).

 - We can't (currently) filter on :ref:`DataUnits <DataUnit>` that *aren't* utilized by the :ref:`DatasetTypes <DatasetType>` produced or consumed by the Pipeline.  That makes it impossible to e.g. filter on :ref:`Tract` if you're just running a single-visit processing Pipeline.  This is not a fundamental limitation, though; we just need to find some way for the user to declare in advance what additional :ref:`DataUnits <DataUnit>` their expression will use.  It'd be best if we could infer that by actually parsing their expression, but if that's hard we could just make them declare the extra :ref:`DataUnits <DataUnit>` explicitly to the activator.

To restrict the query to :ref:`DataUnits <DataUnit>` associated with already-existing input data (``warps``, in this case), we iterate over the :ref:`DatasetTypes <DatasetType>` in the ``neededDatasetTypes`` list and, for each :ref:`DatasetType`, add:

 - the :ref:`Dataset <sql_Dataset>` table to the ``FROM`` list (again as an ``INNER JOIN``), aliased to the :ref:`DatasetType`;

 - the primary key of the :ref:`Dataset <sql_Dataset>` table, ``(dataset_id, registry_id)``, again aliased, to the ``SELECT`` field list;

 - a ``WHERE`` restriction on the aliased :ref:`Dataset <sql_Dataset>` to restrict it to that :ref:`DatasetType`;

 - all :ref:`Dataset-DataUnit join tables <dataset_joins>` for the *minimal* set of :ref:`DataUnits <DataUnit>` needed to identify the current :ref:`DatasetType`;

 - a ``WHERE`` restriction joining the join tables to the aliased :ref:`DatasetType`;

 - a join table and restriction to limit us to the :ref:`Collection(s) <Collection>` arguments passed to :py:meth:`makeDataGraph <Registry.makeDataGraph>`.

In the coaddition example, that makes our full query (now completed):

.. code:: sql

    SELECT
        Visit.visit_number,
        PhysicalFilter.physical_filter_name,
        Camera.camera_name,
        Patch.patch_index,
        Tract.tract_number,
        SkyMap.skymap_name,
        AbstractFilter.abstract_filter_name,
        warp.dataset_id AS warp_dataset_id,
        warp.registry_id AS warp_registry_id
    FROM
        Visit
        INNER JOIN PhysicalFilter
        INNER JOIN Camera
        INNER JOIN Patch
        INNER JOIN Tract
        INNER JOIN SkyMap
        INNER JOIN AbstractFilter
        INNER JOIN VisitPatchJoin
        INNER JOIN Dataset AS warp
        INNER JOIN DatasetVisitJoin AS warpVisitJoin
        INNER JOIN DatasetPatchJoin AS warpPatchJoin
        INNER JOIN DatasetCollections AS warpCollections
    WHERE
        Visit.physical_filter_name = PhysicalFilter.physical_filter_name
            AND
        Visit.camera_name = Camera.camera_name
            AND
        PhysicalFilter.camera_name = Camera.camera_name
            AND
        Patch.tract_number = Tract.tract_number
            AND
        Patch.skymap_name = SkyMap.skymap_name
            AND
        Tract.skymap_name = SkyMap.skymap_name
            AND
        PhysicalFilter.abstract_filter_name = AbstractFilter.abstract_filter_name
            AND
        VisitPatchJoin.visit_number = Visit.visit_number
            AND
        VisitPatchJoin.camera_name = Visit.camera_name
            AND
        VisitPatchJoin.patch_index = Patch.patch_index
            AND
        VisitPatchJoin.tract_number = Patch.tract_number
            AND
        VisitPatchJoin.skymap_name = Patch.skymap_name
            AND
        warp.dataset_type_name = 'warp'
            AND
        warp.dataset_id = warpVisitJoin.dataset_id
            AND
        warp.registry_id = warpVisitJoin.registry_id
            AND
        warpVisitJoin.visit_number = Visit.visit_number
            AND
        warpVisitJoin.camera_name = Visit.camera_name
            AND
        warp.dataset_id = warpPatchJoin.dataset_id
            AND
        warp.registry_id = warpPatchJoin.registry_id
            AND
        warpPatchJoin.patch_index = Patch.patch_index
            AND
        warpPatchJoin.tract_number = Patch.tract_number
            AND
        warpPatchJoin.skymap_name = Patch.skymap_name
            AND
        warpCollections.dataset_id = warp.dataset_id
            AND
        warpCollections.registry_id = warp.registry_id
            AND
        warpCollections.tag = ($USER_TAG)
        ($USER_EXPRESSION)
    ;

.. note::

    The example above demonstrates using only a single :ref:`Collection`.
    Handling multiple :ref:`Collections <Collection>` is quite a bit trickier.
    It can obviously be accomplished with temporary tables, views, or subqueries that create a de-duplicated list of :ref:`Datasets <Dataset>` for each :ref:`DatasetType` across all given :ref:`Collections <Collection>` before joining them into the main query.
    It is not clear whether it can be accomplished directly within a single query with no subqueries.

Adding the :ref:`Dataset` fields to the ``SELECT`` field list is clearly unnecessary for constraining the query; that all happens in the ``WHERE`` clause.
What these do is identify the set of input :ref:`Datasets <Dataset>` that will be used by the processing.
In this example, each row has a unique (compound) ``warp`` ID, but that's not always true - to be safe in general, duplicates will have to be removed.

As written, this query doesn't pull down *everything* about the :ref:`Datasets <Dataset>`.
Including all of the fields that describe a :ref:`Dataset` in the same query is clearly possible (albeit a bit tricky in the case of composites), but it's not obviously more efficient than running smaller follow-up queries to get the extra Dataset fields when the original query may have a lot of duplicates.

We actually face the same problem for the extra fields associated with the :ref:`DataUnits <DataUnit>`; our query so far generates all of the primary key values and relationship information we'll need, but we'll need to follow that up with later queries to fill in the extra fields or add a lot more fields.
And as with the :ref:`Datasets <Dataset>`, we could instead add the extra fields to the main query, but doing so will in general involve a lot of duplicate values.

We will assume for now that we'll leave the main query as-is and use follow-up queries to expand its results into a list of :py:class:`DatasetHandles <DatasetHandle>` that we can add to the :py:class:`QuantumGraph`.
As noted above, the :ref:`DataUnit` primary keys from the main query are sufficient to construct a :py:class:`DataUnitMap` to attach to it, and the implementation of :py:meth:`Registry.makeDataGraph` is complete.


Fine-Grained Input Control
^^^^^^^^^^^^^^^^^^^^^^^^^^
The tags and expression passed to :py:meth:`Registry.makeDataGraph` provide a level of control over processing inputs that should be sufficient for most SuperTask execution invoked by developers and science users.
That level of control may not be sufficient for production operators, however -- though in most cases, it's actually that exercising the levels of control operators require may be unpleasant or inconvenient.

That's because the :ref:`Collection` tag system is already extremely flexible.
As long as an operator is permitted to apply tags to :ref:`Datasets <Dataset>` in the database that backs a :ref:`Registry` (which may not involve going through the :ref:`Registry` interface, they can create a :ref:`Collection` including (and more importantly, not including) any :ref:`Datasets <Dataset>` they'd like, whether that's generated by one or more SQL queries, external programs, or human inspections.
This mechanism should be strongly considered as at least part of any implentation of a fine-grained control use case before we add additional logic to :py:meth:`Registry.makeDataGraph`.
We will, after all, be adding all input data to the :ref:`Collection` associated with each :ref:`Run` during the course of preflight anyway, and it is perfectly acceptable to do this prior to preflight and then use that existing :ref:`Collection` to label the :ref:`Run` (making the later assignment of the input data to that :ref:`Collection` a no-op).

Two types of fine-grained control stand out as being difficult (perhaps impossible) to handle with just :ref:`Collections <Collection>`:

 - blacklists that apply to only some processing steps, not all of them;
 - manual alterations of the relationships between raw science images and master calibration :ref:`Datasets <Dataset>`.

The current system could easily be extended to support these use cases in other ways, however:

 - Blacklisting that only applies to a single SuperTask could be implemented as a blacklist  :ref:`Dataset` (possibly a database-backed one) that is passed to the SuperTask's ``defineQuanta`` method and applied there.  This would require adding some mechanism for passing :ref:`Datasets <Dataset>` to ``defineQuanta`` without permitting SuperTasks to load arbitrary :ref:`Datasets <Dataset>` at that stage.

 - Manual alterations of calibration product relationships could be implemented by creating a new set of :ref:`MasterCalib` :ref:`DataUnits <DataUnit>` and assigning existing them to new :ref:`Datasets <Dataset>` in a new :ref:`Collection` whose :ref:`URIs <URI>` are taken from existing :ref:`Datasets <Dataset>`.  We'd need to think through the implications of having multiple :ref:`Datasets <Dataset>` with the same :ref:`URIs <URI>`, and we'd certainly need some new high-level code to make this easy to do.

This does not rule out adding new logic and arguments to :py:meth:`Registry.makeDataGraph` to meet fine-grained input control requirements, of course, and it is also possible that we could let operators write the entire query generated by :py:meth:`makeDataGraph <Registry.makeDataGraph>` manually.
The complexity of the those queries makes writing them manually from scratch a significant ask, of course, so it might be best to instead let operators *modify* a generated query after it has been generated.
That would generally involve editing only the ``FROM`` and ``WHERE`` clauses, as downstream code that interprets the query results would require the field list to remain unchanged.

Because a single query is used to define the inputs for all processing steps, however, even manual control over the query would not permit operators to control which inputs are used in different steps independently.
Complete operator control over that would probably have to involve generating :ref:`Quanta <Quantum>` to pass to ``SuperTask.runQuantum`` manually, without calling ``defineQuanta`` or other standard preflight code at all.
While probably possible (and perhaps not even too difficult) for a fixed Pipeline, this would make it harder to propagate changes to the Pipeline into the production system.
It also raises a fundamental philosophical question about the degree of determinism (vs. runtime flexibility) we expect from a particular release of Science Pipelines code, because it makes it impossible to guarantee that input-selection logic will be the same in production as it was in development.


.. _direct_supertask_execution:

Direct Execution
----------------

This section describes executing SuperTasks in an environment in which the same output :ref:`Registry` and :ref:`Datastore` used for preflight are directly accessible to the worker processes.
See :ref:`shared_nothing_supertask_execution` for SuperTask execution in an environment where workers cannot access the :ref:`Datastore` or the output :ref:`Registry`.

#. The activator constructs an input/output :ref:`Butler` with the same :ref:`Registry` and :ref:`Datastore` used in preflight.

#. The activator loops over all :ref:`Quanta <Quantum>` it has been assigned by the workflow system.  For each one, it:

    #. adds the :ref:`Quantum` to the :ref:`Registry` by calling :py:meth:`Registry.addQuantum`.  This stores the :py:attr:`predictedInputs <Quantum.predictedInputs>` provenance in the :ref:`Registry`;

    #. transforms all :py:attr:`predictedInputs <Quantum.predictedInputs>` :py:class:`DatasetRefs <DatasetRef>` into :py:class:`DatasetHandles <DatasetHandle>`, allowing the control code to test whether all needed inputs are present before actually invoking SuperTask code;

    #. calls ``SuperTask.runQuantum`` with the :py:class:`Quantum` instance and the :py:class:`Butler` instance.  The SuperTask calls :py:meth:`Butler.get` (using the :ref:`DatasetRefs <DatasetRef>` in :py:attr:`Quantum.predictedInputs`) to obtain its inputs, and indicates the ones it actually utilizes by calling :py:meth:`Butler.markInputUsed`.  Outputs are saved with :py:meth:`Butler.put`, which is passed the :py:class:`Quantum` instance to automatically record :py:attr:`outputs <Quantum.outputs>` provenance.

If the SuperTask throws an exception or otherwise experiences a fatal error, the :ref:`Quantum` that defined its execution will thus have already been added to the :ref:`Registry` whith as much information as possible about its inputs and outputs, maximizing its use in debugging the failure.


.. _shared_nothing_supertask_execution:

Shared-Nothing Execution
------------------------

.. todo::

    Fill this in.  Run directly against a "limited" Registry (e.g. backed by just a YAML file) and local Datastore (e.g. backed by a simple POSIX directory) that are proxies for the full ones.  Show how to do the staging transfers through our interfaces *and* how to get the necessary information (e.g. filenames) to do them externally.


.. _running_comparison_supertasks:

Running Comparison SuperTasks
-----------------------------

SuperTasks that compare their input :ref:`Datasets <Dataset>`, and hence wish to access :ref:`Datasets <Dataset>` with the same :ref:`DataUnits <DataUnit>` in different :ref:`Collections <Collection>`, were not anticipated by the original SuperTask design and are not included in the description of SuperTask covered above.

These can be supported by the current data access design, with the following qualifications:

 - As executing a Pipeline always outputs to a single :ref:`Run` and a single :ref:`Collection`, only one of the :ref:`Collections <Collection>` being compared by a SuperTask can have outputs written to it by the same Pipeline that includes the comparison SuperTask.  For example, this allows a Pipeline that processes data to also include a SuperTask that compares the results to an existing :ref:`Collection`, but it does not permit different configurations of the same Pipeline to be executed and compared in a single step.

 - The contents of one :ref:`Collection` shall be used to construct the :ref:`QuantumGraph` that defines the full execution plan.  This makes it impossible to e.g. process only :ref:`DatasetRefs <DatasetRef>` for which a :ref:`Dataset` exists in all compared :ref:`Collections <Collection>`.  It also means that the ``defineQuanta`` method for comparison SuperTasks should expect to see only one :ref:`DatasetRef` of any set to be compared *at this time*.

To implement Preflight for a Pipeline containing comparison SuperTasks, then, the activator simply executes the normal Preflight process on one of the :ref:`Collections <Collection>` to be compared.
The activator then walks the resulting :ref:`QuantumGraph`, identifying any :ref:`DatasetRefs <DatasetRef>` that represent comparisons by some combination of task names and :ref:`DatasetType` names obtainable from the Pipeline.
For each of these, it searches for matching :py:class:`DatasetHandles <DatasetHandle>` in the other :ref:`Collections <Collection>` and attaches these to the :ref:`Quantum` as additional inputs.  SuperTask execution can then be run as usual.

This adds a few small requirements on the interfaces of some of the classes involved:

 - When passed a :py:class:`DatasetHandle`, :ref:`Butler` must permit it to be loaded using the :ref:`URI` (and any component :ref:`URIs <URI>`) it holds, rather than interpreting it as a :py:class:`DatasetRef` to be combined with the :ref:`Butler's <Butler>` own :ref:`Collection` to obtain a new :ref:`URI`.  This has been added to the design as :py:meth:`Butler.getDirect`.

 - The container type used to implement :py:attr:`Quantum.predictedInputs` must be able to hold multiple :py:class:`DatasetHandles <DatasetHandle>` that appear equivalent when compared as :py:class:`DatasetRefs <DatasetRef>`.

 - Either :py:class:`DatasetHandle` or the :py:attr:`Quantum.predictedInputs` container must provide a way for the SuperTask to ascertain which of the input :ref:`Collections <Collection>` it was retreived from.

DataUnit Updates and Inserts
============================

.. todo::

    Fill these sections in.  Make sure to handle :ref:`dataunit_joins`.

Raw Data Ingest
---------------

Making Master Calibrations
--------------------------

Defining SkyMaps
----------------

