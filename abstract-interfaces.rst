
Abstract Interfaces
===================

.. _Registry:

Registry
--------

A database that holds metadata, relationships, and provenance for managed :ref:`Datasets <Dataset>`.

Many Registry implementations will consist of both a client and a server (though the server will frequently be just a database server with no additional code).

A Registry is almost always backed by a SQL database (e.g. `PostgreSQL`, `MySQL` or `SQLite`) that exposes a schema common to all Registries, described in the many "SQL Representation" sections of this document.  As the common schema is used only for SELECT queries, concrete Registries can implement it as set of direct tables, a set of views against private tables, or any combination thereof.

In some important contexts (e.g. processing data staged to scratch space), only a small subset of the full Registry interface is needed, and we may be able to utilize a simple key-value database instead.  These are called *limited* Registries.
A limited Registry implements only a small subset of the full Registry Python interface and has no SQL interface at all, and methods that would normally accept :py:class:`DatasetLabel` require a full :py:class:`DatasetRef` instead.
In general, limited Registries have enough functionality to support :py:meth:`Butler.get` and :py:meth:`Butler.put`, but no more.
A limited Registry may be implented on top of a simple persistent key-value store (e.g. a YAML file) rather than a full SQL database.
The operations supported by a limited Registry are indicated in the Python API section below.

.. note::

    Limited registries that are used on scratch space during processing need to handle provenance and can require DatasetRefs instead of just DatasetLabels, but dumb ones used for one-off, interactive work do not need provenance and would want to use DatasetLabels.
    We should probably formalize the different levels of functionality required of Registries in different contexts as different Python class interfaces (with a possibly-multiple inheritance relationship).

Transition
^^^^^^^^^^

The v14 Butler's Mapper class contains a Registry object that is also implemented as a SQL database, but the new Registry concept differs in several important ways:

 - new Registries can hold multiple Collections, instead of being identified strictly with a single Data Repository;
 - new Registries also assume most of the responsibilities of the v14 Butler's Mapper;
 - non-limited Registries now have a much richer set of tables, permitting many more types of queries.

Python API
^^^^^^^^^^

.. py:class:: Registry

    .. py:method:: query(sql, parameters)

        Execute an arbitrary SQL SELECT query on the Registry's database and return the results.

        The given SQL statement should be restricted to the schema and SQL dialect common to all Registries, but Registries are not required to check that this is the case.

        .. todo::

            This should be a very simple pass-through to SQLAlchemy or a DBAPI driver.  Should be made explicit about exactly what that means for parameters and returned objects.

        *Not supported by limited Registries.*

    .. py:method:: registerDatasetType(datasetType)

        Add a new :ref:`DatasetType` to the Registry.

        :param DatasetType datasetType: the :ref:`DatasetType` to be added

        :return: None

        *Not supported by limited Registries.*

        .. todo::

            If the new DatasetType already exists, we need to make sure it's consistent with what's already present, but if it is, we probably shouldn't throw.
            Need to see if there's also a use case for throwing if the DatasetType exists or overwriting if its inconsistent.

    .. py:method:: getDatasetType(name)

        Return the :py:class:`DatasetType` associated with the given name.

    .. py:method:: addDataset(ref, uri, components, producer=None, run=None)

        Add a :ref:`Dataset` to a :ref:`Collection`.

        This always adds a new :ref:`Dataset`; to associate an existing :ref:`Dataset` with a new :ref:`Collection`, use :py:meth:`associate`.

        The :ref:`Quantum` that generated the :ref:`Dataset` can optionally be provided to add provenance information.

        :param ref: a :ref:`DatasetRef` that identifies the :ref:`Dataset` and contains its :ref:`DatasetType`.

        :param str uri: the :ref:`URI` that has been associated with the :ref:`Dataset` by a :ref:`Datastore`.

        :param dict components: if the :ref:`Dataset` is a composite, a ``{name : URI}`` dictionary of its named components and storage locations.

        :param Run run: the :ref:`Run` instance that produced the Dataset.  Ignored if ``producer`` is passed (:py:attr:`producer.run <Quantum.run>` is then used instead).  A Run must be provided by one of the two arguments.

        :param Quantum producer: the Quantum instance that produced the Dataset.  May be ``None`` to store no provenance information, but if present the :py:class:`Quantum` must already have been added to the Registry.

        :return: a newly-created :py:class:`DatasetHandle` instance.

        :raises: an exception if a :ref:`Dataset` with the given :ref:`DatasetRef` already exists in the given :ref:`Collection`.

    .. py:method:: associate(tag, handles)

        Add existing :ref:`Datasets <Dataset>` to a :ref:`Collection`, possibly creating the :ref:`Collection` in the process.

        :param str tag: a :ref:`CollectionTag <Collection>` indicating the Collection the :ref:`Datasets <Dataset>` should be associated with.

        :param list[DatasetHandle] handles: a list of :py:class:`DatasetHandle` instances that already exist in this :ref:`Registry`.

        :return: None

        *Not supported by limited Registries.*

    .. py:method:: makeRun(tag)

        Create a new :ref:`Run` in the :ref:`Registry` and return it.

        :param str tag: the :ref:`CollectionTag <Collection>` used to identify all inputs and outputs of the :ref:`Run`.

        :returns: a :py:class:`Run` instance.

        *Not supported by limited Registries.*

    .. py:method:: updateRun(run)

        Update the ``environment`` and/or ``pipeline`` of the given Run in the database, given the :py:class:`DatasetHandles <DatasetHandle>` attributes of the given :py:class:`Run`.

        *Not supported by limited Registries.*

    .. py:method:: addQuantum(quantum)

        Add a new :ref:`Quantum` to the :ref:`Registry`.

        :param Quantum quantum: a :py:class:`Quantum` instance to add to the :ref:`Registry`.

        The given Quantum must not already be present in the Registry (or any other); its :py:attr:`pkey <Quantum.pkey>` attribute must be ``None``.

        The :py:attr:`predictedInputs <Quantum.predictedInputs>` attribute must be fully populated with :py:class:`DatasetHandles <DatasetHandle>`.
        The :py:attr:`actualInputs <Quantum.actualInputs>` and :py:attr:`outputs <Quantum.outputs>` will be ignored.

    .. py:method:: markInputUsed(quantum, handle)

        Record the given :py:class:`DatasetHandle` as an actual (not just predicted) input of the given :ref:`Quantum`.

        This updates both the Registry's :ref:`Quantum <sql_Quantum>` table and the Python :py:attr:`Quantum.actualInputs` attribute.

        Raises an exception if ``handle`` is not already in the predicted inputs list.

    .. py:method:: addDataUnit(unit, replace=False)

        Add a new :ref:`DataUnit`, optionally replacing an existing one (for updates).

        :param DataUnit unit: the :py:class:`DataUnit` to add or replace.

        :param bool replace: if True, replace any matching :ref:`DataUnit` that already exists (updating its non-unique fields) instead of raising an exception.

        *Not supported by limited Registries.*

        .. todo::

            This will need to update many-to-many join tables between DataUnits in some cases.
            We may want to vectorize this operation or otherwise allow many new DataUnits to be added before updating the join tables.

    .. py:method:: findDataUnit(cls, pkey)

        Return a :ref:`DataUnit` given the values of its primary key.

        :param type cls: a class that inherits from :py:class:`DataUnit`.

        :param tuple pkey: a tuple of primary key values that uniquely identify the :ref:`DataUnit`; see :py:attr:`DataUnit.pkey`.

        :returns: a :py:class:`DataUnit` instance of type ``cls``, or ``None`` if no matching unit is found.

        See also :py:meth:`DataUnitMap.findDataUnit`.

        *Not supported by limited Registries.*

    .. py:method:: expand(label)

        Expand a :py:class:`DatasetLabel`, returning an equivalent :py:class:`DatasetRef`.

        Must be a simple pass-through if ``label`` is already a :ref:`DatasetRef`.

        *For limited Registries,* ``label`` *must be a* :py:class:`DatasetRef` *, making this a guaranteed no-op (but still callable, for interface compatibility).*

    .. py:method:: find(tag, label)

        Look up the location of the :ref:`Dataset` associated with the given :py:class:`DatasetLabel`.

        This can be used to obtain the :ref:`URI` that permits the :ref:`Dataset` to be read from a :ref:`Datastore`.

        Must be a simple pass-through if ``label`` is already a :py:class:`DatasetHandle`.

        :param str tag: a :ref:`CollectionTag <Collection>` indicating the :ref:`Collection` to search.

        :param DatasetLabel label: a :py:class:`DatasetLabel` that identifies the :ref:`Dataset`.  *For limited Registries, must be a* :py:class:`DatasetRef`.

        :returns: a :py:class:`DatasetHandle` instance

    .. py:method:: makeDataGraph(tags, expr, neededDatasetTypes, futureDatasetTypes)

        Evaluate a filter expression and lists of :ref:`DatasetTypes <DatasetType>` and return a :ref:`QuantumGraph`.

        :param list[str] tags: an ordered list of tags indicating the :ref:`Collections <Collection>` to search for :ref:`Datasets <Dataset>`.

        :param str expr: an expression that limits the :ref:`DataUnits <DataUnit>` and (indirectly) the :ref:`Datasets <Dataset>` returned.

        :param list[DatasetType] neededDatasetTypes: the list of :ref:`DatasetTypes <DatasetType>` whose instances should be included in the graph and limit its extent.

        :param list[DatasetType] futureDatasetTypes: the list of :ref:`DatasetTypes <DatasetType>` whose instances may be added to the graph later, which requires that their :ref:`DataUnit` types must be present in the graph.

        :returns: a :ref:`QuantumGraph` instance with a :py:attr:`QuantumGraph.units` attribute that is not ``None``.

        *Not supported by limited Registries.*

        .. todo::

            More complete description for expressions.

    .. py:method:: subset(tag, expr, datasetTypes)

        Create a new :ref:`Collection` by subsetting an existing one.

        :param str tag: a :ref:`CollectionTag <Collection>` indicating the input :ref:`Collection` to subset.

        :param str expr: an expression that limits the :ref:`DataUnits <DataUnit>` and (indirectly) the :ref:`Datasets <Dataset>` in the subset.

        :param list[DatasetType] datasetTypes: the list of :ref:`DatasetTypes <DatasetType>` whose instances should be included in the subset.

        :returns: a str :ref:`CollectionTag <Collection>`

        *Not supported by limited Registries.*

        .. todo::

            This should probably have the same signature as makeDataGraph; since that implies it can merge as it subsets, it might need a new name.

    .. py:method:: merge(outputTag, inputTags)

        Create a new :ref:`Collection` from a series of existing ones.

        Entries earlier in the list will be used in preference to later entries when both contain :ref:`Datasets <Dataset>` with the same :ref:`DatasetRef`.

        :param outputTag: a str :ref:`CollectionTag <Collection>` to use for the new :ref:`Collection`.

        :param list[str] inputTags: a list of :ref:`CollectionTags <Collection>` to combine.

        *Not supported by limited Registries.*

    .. py:method:: makeProvenanceGraph(expr, types=None)

        Return a :ref:`QuantumGraph` that contains the full provenance of all :ref:`Datasets <Dataset>` matching an expression.

        :param str expr: an expression (SQL query that evaluates to a list of ``dataset_id``) that selects the :ref:`Datasets <Dataset>`.

        :return: a :py:class:`QuantumGraph` instance (with :py:attr:`units <QuantumGraph.units>` set to None).

        .. todo::

            Should have convenience versions that operate on e.g. DatasetHandles provided by the user.

    .. py:method:: export(expr) -> TableSet

        Export contents of the :ref:`Registry`, limited to those reachable from the :ref:`Datasets <Dataset>` identified
        by the expression ``expr``, into a :ref:`TableSet` format such that it can be imported into a different database.

        :param str expr: an expression (SQL query that evaluates to a list of ``dataset_id``) that selects the :ref:`Datasets <Dataset>`.

        :returns: a :ref:`TableSet` containing all rows, from all tables in the :ref:`Registry` that are reachable from the selected :ref:`Datasets <Dataset>`.

        *Not supported by limited Registries.*

        .. todo::

            Should have convenience versions that operate on e.g. DatasetHandles provided by the user.
            Should also have a version that operates on a QuantumGraph; that may also permit some optimizations, especially if :py:attr:`QuantumGraph.units` is not ``None``.

    .. py:method:: import(tables, tag)

        Import (previously exported) contents into the (possibly empty) :ref:`Registry`.

        :param TableSet tables: a :ref:`TableSet` containing the exported content.

        :param str tag: an additional CollectionTag assigned to the newly imported :ref:`Datasets <Dataset>`.

        *Limited Registries will import only some of the information exported by full Registry.*

    .. py:method:: transfer(src, expr, tag)

        Transfer contents from a source :ref:`Registry`, limited to those reachable from the :ref:`Datasets <Dataset>` identified
        by the expression ``expr``, into this :ref:`Registry` and tag them with a :ref:`Collection`.

        :param Registry src: the source :ref:`Registry`.

        :param str expr: an expression that limits the :ref:`DataUnits <DataUnit>` and (indirectly) the :ref:`Datasets <Dataset>` transferred.

        :param str tag: an additional CollectionTag assigned to the newly imported :ref:`Datasets <Dataset>`.


        Trivially implemented as:

        .. code:: python

            def transfer(self, src, expr, tag):
                self.import(src.export(expr), tag)


.. _Datastore:

Datastore
---------

A system that holds persisted :ref:`Datasets <Dataset>` and can read and optionally write them.

This may be based on a (shared) filesystem, an object store, a SQL database, or some other system.

Many Datastore implementations will consist of both a client and a server.

Transition
^^^^^^^^^^

Datastore represents a refactoring of some responsibilities previously held by the v14 Butler and Mapper objects.

Datastore implementations are the most likely place in the new design where existing v14 Butler code could be used.

Python API
^^^^^^^^^^

.. py:class:: Datastore

    .. py:method:: get(uri, parameters=None)

        Load an :ref:`InMemoryDataset` from the store.

        :param str uri: a :ref:`URI` that specifies the location of the stored :ref:`Dataset`.

        :param dict parameters: :ref:`StorageClass`-specific parameters that specify a slice of the :ref:`Dataset` to be loaded.

        :returns: an :ref:`InMemoryDataset` or slice thereof.

    .. py:method:: put(inMemoryDataset, storageClass, path, typeName=None) -> URI, {name: URI}

        Write a :ref:`InMemoryDataset` with a given :ref:`StorageClass` to the store.

        :param inMemoryDataset: the :ref:`InMemoryDataset` to store.

        :param StorageClass storageClass: the :ref:`StorageClass` associated with the :ref:`DatasetType`.

        :param str path: A :ref:`Path` that provides a hint that the :ref:`Datastore` may use as (part of) the :ref:`URI`.

        :param str typeName: The :ref:`DatasetType` name, which may be used by the :ref:`Datastore` to override the default serialization format for the :ref:`StorageClass`.

        :returns: the :py:class:`str` :ref:`URI` and a dictionary of :ref:`URIs <URI>` for the :ref:`Dataset's <Dataset>` components.  The latter will be empty (or None?) if the :ref:`Dataset` is not a composite.

    .. py:method:: transfer(inputDatastore, inputUri, storageClass, path, typeName=None) -> URI, {name: URI}

        Retrieve a :ref:`Dataset` with a given :ref:`URI` from an input :ref:`Datastore`,
        and store the result in this :ref:`Datastore`.

        :param Datastore inputDatastore: the external :ref:`Datastore` from which to retreive the :ref:`Dataset`.

        :param str inputUri: the :ref:`URI` of the :ref:`Dataset` in the input :ref:`Datastore`.

        :param StorageClass storageClass: the :ref:`StorageClass` associated with the :ref:`DatasetType`.

        :param str path: A :ref:`Path` that provides a hint that this :ref:`Datastore` may use as [part of] the :ref:`URI`.

        :param str typeName: The :ref:`DatasetType` name, which may be used by this :ref:`Datastore` to override the default serialization format for the :ref:`StorageClass`.

        :returns: the :py:class:`str` :ref:`URI` and a dictionary of :ref:`URIs <URI>` for the :ref:`Dataset's <Dataset>` components.  The latter will be empty (or None?) if the :ref:`Dataset` is not a composite.

        .. todo::

            This interface does not permit composite datasets stored as separate compoonents to be transferred into a single file.
            We have a clear use case for that, but it probably can't be done with a signature that transfers one Dataset at a time.

.. _TableSet:

TableSet
--------

A serialializable set of exported database tables.

.. note::

    A :ref:`TableSet` does not need to cointain all information needed to recreate the database
    tables themselves (since the tables are part of the common schema), but should contain all
    nessesary information to recreate all the content within them.

Transition
^^^^^^^^^^

.. todo::

    Fill in transition details.

Python API
^^^^^^^^^^

.. todo::

    Specify Python API.

