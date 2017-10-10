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

    The :ref:`Datastore` request can be a simple ``HTTP GET`` request for a stored FITS file, or something more complicated.
    In the former case the materialization would be a simple FITS read (e.g. of a ``calexp``), with the reader determined by the :ref:`StorageClass` retrieved from the :ref:`Registry`.

.. note::

    The serialized version sent over the wire doesn't have to correspond to the format stored on disk in the :ref:`Datastore` server.  It just needs to be serialized in the form expected by the client.

Basic ``put``
-------------

The user has a :ref:`InMemoryDataset` and wishes to store this at a particular :py:class:`DatasetLabel`.

This proceeds allong the following steps:

1. User calls: ``butler.put(label, inMemoryDataset)``.
2. :ref:`Butler` expands the :py:class:`DatasetLabel` into a full :py:class:`DatasetRef` using the :ref:`Registry`, by calling ``datasetRef = butler.registry.getStorageClass(butler.config.outputCollection, datasetRef)``.
3. :ref:`Butler` obtains a :ref:`Path` by calling ``path = datasetRef.makePath(butler.config.outputCollection, template)``. This path is a hint to be used by the :ref:`Datastore` to decide where to store it.  The template is provided by the :ref:`Registry` but may be overridden by the :ref:`Butler`.
4. :ref:`Butler` then asks the :ref:`Datastore` client to store the file by calling: ``butler.datastore.put(inMemoryDataset, datasetRef.type.storageClass, path)``.
5. The :ref:`Datastore` client then uses the serialization function associated with the :ref:`StorageClass` to serialize the :ref:`InMemoryDataset` and sends it to the :ref:`Datastore` server.
   Depending on the type of server it may get back the actual :ref:`URI` or the client can generate it itself.
6. :ref:`Datastore` returns the actual :ref:`URI` to the :ref:`Butler`.
7. :ref:`Butler` calls the :ref:`Registry` function ``addDataset`` to add the :ref:`Dataset` to the collection.
8. :ref:`Butler` returns a :py:class:`DatasetHandle` to the user.

See :py:class:`the API documentation <Butler.put>` for more information.

.. _composites:

Composites
==========

A :ref:`Dataset` can be **composite**, in which case it consists of a **parent** :ref:`Dataset` and one or more child :ref:`Datasets <Dataset>`.  An example would be an ``Exposure`` which consists of a ``Wcs`` a ``Mask`` and an ``Image``.  There are several ways this may be stored by the :ref:`Datastore`:

* As part of the parent :ref:`Dataset` (e.g. the full ``Exposure`` is written to a single FITS file).
* As a set of entities without a parent (e.g. only the ``Wcs``, ``Mask`` and ``Image`` are written separately and the ``Exposure`` needs to be composed from them).
* As a mix of the two extremes (e.g. the ``Mask`` and ``Image`` are part of the ``Exposure`` file but the ``Wcs`` is written to a separate file).

In either case the user expects to be able to read an individual component, and in case the components are stored separately the transfer should be efficient.

In addition, it is desirable to **override** parts of a composite :ref:`Dataset` (e.g. updated metadata).

To support this the :ref:`Registry` is also responsible for storing the component :ref:`Datasets <Dataset>` of the **composite**.

The :py:class:`DatasetHandle` returned by :py:meth:`Registry.find` therefore not only includes the :ref:`URI` and :ref:`StorageClass` of the **parent** (associated with the :ref:`DatasetRef`), but also a ``components`` dictionary of ``name : DatasetHandle`` specifying its **children**.

The :ref:`Butler` retrieves **all** :ref:`Datasets <Dataset>` from the :ref:`Datastore` as :ref:`InMemoryDatasets <InMemoryDataset>` and then calls the ``assemble`` function associated with the :ref:`StorageClass` of the primary to create the final composed :ref:`InMemoryDataset`.

This process is most easily understood by reading the API documentation for :py:meth:`butler.get <Butler.get>` and :py:meth:`butler.put <Butler.put>`.

.. _transferring_registries_and_datastores:

Transferring Registries and Datastores
======================================

A user has a :ref:`Butler` instance that holds a :ref:`Registry` client instance and a :ref:`Datastore` client instance, both connected to their remote server equivalents. Now the user wants to obtain a local subset of the upstream :ref:`Datasets <Dataset>` (and all related :ref:`DataUnits <DataUnit>`, :ref:`DatasetTypes <DatasetType>` and possibly :ref:`Quanta <Quantum>` and :ref:`Collections <Collection>`) held by the :ref:`Registry`.

There are three cases:

* Transfer a subset of the :ref:`Registry`, but not the actual :ref:`Datasets <Dataset>` held by the :ref:`Datastore`, and
* Transfer both a subset of the :ref:`Registry` and the :ref:`Datasets <Dataset>` themselves.
* *Transfer only the* :ref:`Datasets <Dataset>` *from the* :ref:`Datastore` *but keep the remote* :ref:`Registry`.

We will ignore the last one for now and focus on the first two instead.

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
                dst.registry.addDataset(tag, ref, uri, components, quantum)
        else:
            # The following assumes the old datastore was empty and that the datastore will be
            # read-only.  Otherwise we will have to some chaining.
            dst.datastore = src.datastore


    .. todo::

        * Where does ``quantum`` come from?
        * Should we update instead of add? 
        * What should happen if the composition is different in the output datastore?
        * Can we reuse the list of labels that we get from the initial registry transfer?

Remote Access and Caching
=========================

The user has a :ref:`Butler` instance. This :ref:`Butler` instance holds a local :ref:`Registry` client instance, that is connected to a remote **read-only** :ref:`Registry` server (database). It also holds a local :ref:`Datastore` client that also is connected to a remote :ref:`Datastore`.

The user now calls ``butler.get()`` to obtain an :ref:`InMemoryDataset` from the :ref:`Datastore`. Then does some further processing, and subsequently wants to load the **same** :ref:`InMemoryDataset` again.

This is most easily supported by through a **caching** :ref:`Datastore`. The :ref:`Butler` now holds an instance of the caching :ref:`Datastore` instead. And the caching :ref:`Datastore` in turn holds the client to the remote :ref:`Datastore`.

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

        Direct forward to ``self.datastore.transfer`` (probably).

.. todo::

    * What to when ``parameters`` differ? Should we re-slice?
    * What about ``transfer``?

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

#. Preflight begins with the activator calling :py:class:`Registry.makeDataGraph` with the given expression, list of input tags, and the sets of :ref:`DatasetTypes <DatasetType>` implicit in the Pipeline.
The returned :ref:`QuantumGraph` contains both the full set of input :ref:`Datasets <Dataset>` that may be required and the full set of :ref:`DataUnits <DataUnit>` that will be used to describe any future :ref:`Datasets <Dataset>`.

#. If the output :ref:`Registry` is not the same as the input :ref:`Registry`, the activator transfers (see :ref:`transferring_registries_and_datastores`) all :ref:`Registry` content associated with the :ref:`Datasets <Dataset>` in the graph to the output :ref:`Registry`.

#. The activator calls :py:meth:`Registry.makeRun` on the output :ref:`Registry` with the output :ref:`CollectionTag <Collection>`, obtaining a :py:class:`Run` instance.

#. The activator adds all input :ref:`Datasets <Dataset>` to the :ref:`Run's <Run>` :ref:`Collection`.

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

.. _staged_supertask_execution:

Direct Execution
----------------

This section describes executing SuperTasks in an environment in which the same output :ref:`Registry` and :ref:`Datastore` used for preflight are directly accessible to the worker processes.
See :ref:`staged_supertask_execution` for SuperTask execution in an environment where workers cannot access the :ref:`Datastore` or the output :ref:`Registry`.

#. The activator constructs an input/output :ref:`Butler` with the same :ref:`Registry` and :ref:`Datastore` used in preflight.

#. The activator loops over all :ref:`Quanta <Quantum>` it has been assigned by the workflow system.  For each one, it:

    #. adds the :ref:`Quantum` to the :ref:`Registry` by calling :py:meth:`Registry.addQuantum`.  This stores the "predictedInput" provenance in the :ref:`Registry`;

    #. calls ``SuperTask.runQuantum`` with the :py:class:`Quantum` instance and the :py:class:`Butler` instance.  The SuperTask calls :py:meth:`Butler.get` (using the :ref:`DatasetRefs <DatasetRef>` in :py:attr:`Quantum.predictedInputs`) to obtain its inputs, and indicates the ones it actually utilizes by calling :py:meth:`Butler.markInputUsed`.  Outputs are saved with :py:meth:`Butler.put`, which is passed the :py:class:`Quantum` instance to automatically record "output" provenance.

If the SuperTask throws an exception or otherwise experiences a fatal error, the :ref:`Quantum` that defined its execution will thus have already been added to the :ref:`Registry` which as much information as possible about its inputs and outputs, making it useful for debugging.


.. _shared_nothing_supertask_execution:

Shared-Nothing Execution
------------------------

.. todo::

    Fill this in.  Run directly against a "limited" Registry and local Datastore that are proxies for the full ones.  Show how to do the staging transfers through our interfaces *and* how to get the necessary information (e.g. filenames) to do them externally.


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

