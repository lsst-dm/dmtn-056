
Abstract Interfaces
===================

.. _Registry:

Registry
--------

A database that holds metadata, relationships, and provenance for managed :ref:`Datasets <Dataset>`.

Four different levels of Registry interfaces are defined:

 - :py:class:`BasicInputRegistry` is read-only and provides only enough functionality to support :py:meth:`Butler.get` on a single :ref`:Collection.  It does not require a SQL backend.
 - :py:class:`BasicRegistry` is read-write and provides enough functionality to support :py:meth:`Butler.put` as well as :py:meth:`Butler.get` on a single :ref:`Collection`.  It does not require a SQL backend, but does need to support recording provenance.
 - :py:class:`FullInputRegistry` is read-only with provenance and :ref:`DataUnit` query functionality and support for multiple :ref:`Collection <Collection>`.  It requires a SQL backend.
 - :py:class:`FullRegistry` is read-write, SQL-backed registry with full functionality.

The SQL database that backs a FullRegistry or FullInputRegistry must expose a schema common to all implementations, described in the many "SQL Representation" sections of this document.  As the common schema is used only for SELECT queries, concrete Registries can implement it as set of true tables, a set of views against private tables, or any combination thereof.

Many Registry implementations will consist of both a client and a server (though the server will frequently be just a database server with no additional code).

.. todo::

    Limited registries that are used on scratch space during processing need to handle provenance, but dumb ones used for one-off, interactive work do not.

Transition
^^^^^^^^^^

The v14 Butler's Mapper class contains a Registry object that is also implemented as a SQL database, but the new Registry concept differs in several important ways:

 - some new Registries can hold multiple Collections, instead of being identified strictly with a single Data Repository;
 - new Registries also assume some of the responsibilities of the v14 Butler's Mapper;
 - non-basic new Registries have a much richer set of tables, permitting many more types of queries.

Python API
^^^^^^^^^^

.. py:class:: BasicInputRegistry

    A simple read-only registry that contains only a single Collection and can be implemented without a SQL backend.

    BasicInputRegistry can be used to implement :py:meth:`Butler.get`.

    .. py:method:: getDatasetType(name)

        Return the :py:class:`DatasetType` associated with the given name.

    .. py:method:: find(tag, label)

        Look up the location of the :ref:`Dataset` associated with the given :py:class:`DatasetRef`.

        This can be used to obtain the :ref:`URI` that permits the :ref:`Dataset` to be read from a :ref:`Datastore`.

        Must be a simple pass-through if ``label`` is already a :py:class:`DatasetHandle`.

        :param str tag: a :ref:`CollectionTag <Collection>` indicating the :ref:`Collection` to search (which must match the Collection associated with the Registry, if it only has a single Collection).

        :param DatasetLabel label: a :py:class:`DatasetLabel` that identifies the :ref:`Dataset`.

        :returns: a :py:class:`DatasetHandle` instance

    .. py:method:: expand(label)

        Expand a :py:class:`DatasetLabel`, returning an equivalent :py:class:`DatasetRef`.

        Must be a simple pass-through if ``label`` is already a :ref:`DatasetRef`.


.. py:class:: BasicRegistry(BasicInputRegistry)

    A simple read-write registry that contains only a single :ref:`Collection` and a single :ref:`Run`, and can be implemented without a SQL backend.

    BasicRegistry can be used to implement both :py:meth:`Butler.get` and :py:meth:`Butler.put`, making it sufficient for SuperTask execution.
    Because it can register new :ref:`DatasetTypes <DatasetType>` and create :ref:`Runs <Run>`, it can also be used as the outpur Registry for superTask preflight.

    .. py:method:: registerDatasetType(datasetType)

        Add a new :ref:`DatasetType` to the Registry.

        :param DatasetType datasetType: the :ref:`DatasetType` to be added

        :return: None

        *Not supported by limited Registries.*

        .. todo::

            If the new DatasetType already exists, we need to make sure it's consistent with what's already present, but if it is, we probably shouldn't throw.
            Need to see if there's also a use case for throwing if the DatasetType exists or overwriting if its inconsistent.

    .. py:method:: makeRun(tag)

        Create a new :ref:`Run` in the :ref:`Registry` and return it.

        :param str tag: the :ref:`CollectionTag <Collection>` used to identify all inputs and outputs of the :ref:`Run`.  For single-collection registries, the tag must match that of the registry.

        :returns: a :py:class:`Run` instance.

    .. py:method:: updateRun(run)

        Update the ``environment`` and/or ``pipeline`` of the given Run in the database, given the :py:class:`DatasetHandles <DatasetHandle>` attributes of the given :py:class:`Run`.

    .. py:method:: addQuantum(quantum)

        Add a new :ref:`Quantum` to the :ref:`Registry`.

        :param Quantum quantum: a :py:class:`Quantum` instance to add to the :ref:`Registry`.

        The given Quantum must not already be present in the Registry (or any other); its :py:attr:`pkey <Quantum.pkey>` attribute must be ``None``.

        The :py:attr:`predictedInputs <Quantum.predictedInputs>` attribute must be fully populated with :py:class:`DatasetHandles <DatasetHandle>`.
        The :py:attr:`actualInputs <Quantum.actualInputs>` and :py:attr:`outputs <Quantum.outputs>` will be ignored.

    .. py:method:: addDataset(ref, uri, components, run=None, quantum=None)

        Add a :ref:`Dataset` to the Registry.

        :param DatasetRef ref: a :ref:`DatasetRef` that identifies the :ref:`Dataset` and contains its :ref:`DatasetType`.

        :param str uri: the :ref:`URI` that has been associated with the :ref:`Dataset` by a :ref:`Datastore`.

        :param dict components: if the :ref:`Dataset` is a composite, a ``{name : URI}`` dictionary of its named components and storage locations.

        :param Run run: the Run instance that produced the Dataset.  Falls back to ``quantum.run`` if ``None``, but must be provided if :ref:`Quantum` is ``None``.

        :param Quantum quantum: the Quantum instance that produced the Dataset.  May be ``None`` to store no provenance information, but if present the :py:class:`Quantum` must already have been added to the Registry.

        :return: a newly-created :py:class:`DatasetHandle` instance.

        :raises: an exception if a :ref:`Dataset` with the given :ref:`DatasetRef` already exists.

    .. py:method:: markInputUsed(quantum, handle)

        Record that the given :py:class:`DatasetHandle` as an actual (not just predicted) input of the given :ref:`Quantum`.

        This updates both the Registry's :ref:`Quantum <sql_Quantum>` table and the Python :py:attr:`Quantum.actualInputs` attribute.

        Raises an exception if ``handle`` is not already in the predicted inputs list.


.. py:class:: FullInputRegistry(BasicInputRegistry)

    A read-only registry that may contains multiple :ref:`Collections <Collection>` and provides access to the common SQL schema.

    A FullInputRegistry can be used as the input Registry for SuperTask preflight.
    It also provides the level of functionality that would expected by most validation work, and is a natural fit for public databases exposed to science users.

    .. py:method:: query(sql, parameters)

        Execute an arbitrary SQL SELECT query on the Registry's database and return the results.

        The given SQL statement should be restricted to the schema and SQL dialect common to all Registries, but Registries are not required to check that this is the case.

        .. todo::

            This should be a very simple pass-through to SQLAlchemy or a DBAPI driver.  Should be explicit about exactly what that means for parameters and returned objects.

    .. py:method:: findDataUnit(cls, pkey)

        Return a :ref:`DataUnit` given the values of its primary key.

        :param type cls: a class that inherits from :py:class:`DataUnit`.

        :param tuple pkey: a tuple of primary key values that uniquely identify the :ref:`DataUnit`; see :py:attr:`DataUnit.pkey`.

        :returns: a :py:class:`DataUnit` instance of type ``cls``, or ``None`` if no matching unit is found.

        See also :py:meth:`DataUnitMap.findDataUnit`.

    .. py:method:: makeDataGraph(tags, expr, neededDatasetTypes, futureDatasetTypes)

        Evaluate a filter expression and lists of :ref:`DatasetTypes <DatasetType>` and return a :ref:`QuantumGraph`.

        :param list[str] tags: an ordered list :ref:`CollectionTag <Collection>` indicating the :ref:`Collection` to search for :ref:`Datasets <Dataset>`.

        :param str expr: an expression that limits the :ref:`DataUnits <DataUnit>` and (indirectly) the :ref:`Datasets <Dataset>` returned.

        :param list[DatasetType] neededDatasetTypes: the list of :ref:`DatasetTypes <DatasetType>` whose instances should be included in the graph and limit its extent.

        :param list[DatasetType] futureDatasetTypes: the list of :ref:`DatasetTypes <DatasetType>` whose instances may be added to the graph later, which requires that their :ref:`DataUnit` types must be present in the graph.

        .. todo::

            More complete description for expressions.

        :returns: a :ref:`QuantumGraph` instance with a :py:attr:`QuantumGraph.units` attribute that is not ``None``.

    .. py:method:: makeProvenanceGraph(expr, types=None)

        Return a :ref:`QuantumGraph` that contains the full provenance of all :ref:`Dataset <Dataset>` matching an expression.

        :param str expr: an expression (SQL query that evaluates to a list of ``dataset_id``) that selects the :ref:`Datasets <Dataset>`.

        :return: a :py:class:`QuantumGraph` instance (with :py:attr:`units <QuantumGraph.units>` set to None).

    .. py:method:: export(expr) -> TableSet

        Export contents of the :ref:`Registry`, limited to those reachable from the :ref:`Datasets <Dataset>` identified
        by the expression ``expr``, into a :ref:`TableSet` format such that it can be imported into a different database.

        :param str expr: an expression (SQL query that evaluates to a list of ``dataset_id``) that selects the :ref:`Datasets <Dataset>`.

        :returns: a :ref:`TableSet` containing all rows, from all tables in the :ref:`Registry` that are reachable from the selected :ref:`Datasets <Dataset>`.

        *Not supported by limited Registries.*


.. py:class:: FullRegistry(FullInputRegistry, BasicRegistry)

    A read-write registry that may contains multiple :ref:`Collections <Collection>` and provides access to the common SQL schema.

    A FullRegistry is not strictly required for any SuperTask or Butler operaations, but it provides the functionality necessary to fully manage :ref:`Collections <Collection>` and :ref:`DataUnits <DataUnit>`

    .. py:method:: associate(tag, handles)

        Add existing :ref:`Datasets <Dataset>` to a :ref:`Collection`, possibly creating the :ref:`Collection` in the process.

        :param str tag: a :ref:`CollectionTag <Collection>` indicating the Collection the :ref:`Datasets <Dataset>` should be associated with.

        :param list[DatasetHandle] handles: a list of :py:class:`DatasetHandle` instances that already exist in this :ref:`Registry`.

        :return: None

    .. py:method:: addDataUnit(unit, replace=False)

        Add a new :ref:`DataUnit`, optionally replacing an existing one (for updates).

        :param DataUnit unit: the :py:class:`DataUnit` to add or replace.

        :param bool replace: if True, replace any matching :ref:`DataUnit` that already exists (updating its non-unique fields) instead of raising an exception.

    .. py:method:: merge(outputTag, inputTags)

        Create a new :ref:`Collection` from a series of existing ones.

        Entries earlier in the list will be used in preference to later entries when both contain :ref:`Datasets <Dataset>` with the same :ref:`DatasetRef`.

        :param outputTag: a str :ref:`CollectionTag <Collection>` to use for the new :ref:`Collection`.

        :param list[str] inputTags: a list of :ref:`CollectionTags <Collection>` to combine.

    .. py:method:: subset(tag, expr, datasetTypes)

        Create a new :ref:`Collection` by subsetting an existing one.

        :param str tag: a :ref:`CollectionTag <Collection>` indicating the input :ref:`Collection` to subset.

        :param str expr: an expression that limits the :ref:`DataUnits <DataUnit>` and (indirectly) the :ref:`Datasets <Dataset>` in the subset.

        :param list[DatasetType] datasetTypes: the list of :ref:`DatasetTypes <DatasetType>` whose instances should be included in the subset.

        :returns: a str :ref:`CollectionTag <Collection>`

    .. py:method:: import(tableSet, tag)

        Import (previously exported) contents into the (possibly empty) :ref:`Registry`.

        :param tableSet a :ref:`TableSet` containing the exported content.

        :param tag str: an additional CollectionTag assigned to the newly imported :ref:`Datasets <Dataset>`.

    .. py:method:: transfer(inputRegistry, expr, tag)

        Transfer contents from input :ref:`Registry`, limited to those reachable from the :ref:`Datasets <Dataset>` identified
        by the expression ``expr``, into this :ref:`Registry`.

        Implemented as:

        .. code:: python

            def transfer(self, inputRegistry, expr):
                self.import(inputRegistry.export(expr))

.. _TableSet:

TableSet
--------

A serialializable set of exported database tables.

.. note::

    A :ref:`TableSet` does not need to cointain all information needed to recreate the database
    tables themselves (since the tables are part of the common schema), but should contain all
    nessesary information to recreate all the content within them.

.. _Datastore:

Datastore
---------

A system that holds persisted :ref:`Datasets <Dataset>` and can read and optionally write them.

This may be based on a (shared) filesystem, an object store or some other system.

Many Datastore implementations will consist of both a client and a server.

Transition
^^^^^^^^^^

Datastore represents a refactoring of some responsibilities previously held by the v14 Butler and Mapper objects.

Python API
^^^^^^^^^^

.. py:class:: Datastore

    .. py:method:: get(uri, parameters=None)

        Load a :ref:`InMemoryDataset` from the store.

        :param str uri: a :ref:`URI` that specifies the location of the stored :ref:`Dataset`.

        :param dict parameters: :ref:`StorageClass`-specific parameters that specify a slice of the :ref:`Dataset` to be loaded.

        :returns: an :ref:`InMemoryDataset` or slice thereof.

    .. py:method:: put(inMemoryDataset, storageClass, path, typeName=None) -> URI, {name: URI}

        Write a :ref:`InMemoryDataset` with a given :ref:`StorageClass` to the store.

        :param inMemoryDataset: the :ref:`InMemoryDataset` to store.

        :param StorageClass storageClass: the :ref:`StorageClass` associated with the :ref:`DatasetType`.

        :param str path: A :ref:`Path` that provides a hint that the :ref:`Datastore` may use as [part of] the :ref:`URI`.

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

