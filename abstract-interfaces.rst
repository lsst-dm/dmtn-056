
Abstract Interfaces
===================

.. _Registry:

Registry
--------

A database that holds metadata, relationships, and provenance for managed :ref:`Datasets <Dataset>`.

A Registry is almost always backed by a SQL database (e.g. `PostgreSQL`, `MySQL` or `SQLite`) that exposes a schema common to all Registries, described in the many "SQL Representation" sections of this document.  As the common schema is used only for SELECT queries, concrete Registries can implement it as set of direct tables, a set of views against private tables, or any combination thereof.

In some important contexts (e.g. processing data staged to scratch space), only a small subset of the full Registry interface is needed, and we may be able to utilize a simple key-value database instead.

Many Registry implementations will consist of both a client and a server (though the server will frequently be just a database server with no additional code).

A *limited* Registry implements only a small subset of the full Registry Python interface and has no SQL interface at all, and methods that would normally accept :py:class:`DatasetLabel` require a full :py:class:`DatasetRef` instead.
In general, limited Registries have enough functionality to support :py:meth:`Butler.get` and :py:meth:`Butler.put`, but no more.
A limited Registry may be implented on top of a simple persistent key-value store (e.g. a YAML file) rather than a full SQL database.
The operations supported by a limited Registry are indicated in the Python API section below.

Transition
^^^^^^^^^^

The v14 Butler's Mapper class contains a Registry object that is also implemented as a SQL database, but the new Registry concept differs in several important ways:

 - new Registries can hold multiple Collections, instead of being identified strictly with a single Data Repository;
 - new Registries also assume some of the responsibilities of the v14 Butler's Mapper;
 - new Registries have a much richer set of tables, permitting many more types of queries.

Python API
^^^^^^^^^^

.. py:class:: Registry

    .. py:method:: query(sql, parameters)

        Execute an arbitrary SQL SELECT query on the Registry's database and return the results.

        The given SQL statement should be restricted to the schema and SQL dialect common to all Registries, but Registries are not required to check that this is the case.

        .. todo::

            This should be a very simple pass-through to SQLAlchemy or a DBAPI driver.  Should be explicit about exactly what that means for parameters and returned objects.

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

    .. py:method:: addDataset(tag, label, uri, components, quantum=None)

        Add a :ref:`Dataset` to a :ref:`Collection`.

        This always adds a new :ref:`Dataset`; to associate an existing :ref:`Dataset` with a new :ref:`Collection`, use :py:meth:`associate`.

        The :ref:`Quantum` that generated the :ref:`Dataset` can optionally be provided to add provenance information.

        :param str tag: a :ref:`CollectionTag <Collection>` indicating the :ref:`Collection` the :ref:`DatasetType` should be associated with.

        :param DatasetRef ref: a :ref:`DatasetRef` that identifies the :ref:`Dataset` and contains its :ref:`DatasetType`.

        :param str uri: the :ref:`URI` that has been associated with the :ref:`Dataset` by a :ref:`Datastore`.

        :param dict components: if the :ref:`Dataset` is a composite, a ``{name : URI}`` dictionary of its named components and storage locations.

        :return: a newly-created :py:class:`DatasetHandle` instance.

        :raises: an exception if a :ref:`Dataset` with the given :ref:`DatasetRef` already exists in the given :ref:`Collection`.

    .. py:method:: associate(tag, handle)

        Add an existing :ref:`Dataset` to an existing :ref:`Collection`.

        :param str tag: a :ref:`CollectionTag <Collection>` indicating the Collection the :ref:`DatasetType` should be associated with.

        :param DatasetHandle handle: a :py:class:`DatasetHandle` instance that already exists in another :ref:`Collection` in this :ref:`Registry`.

        :return: None

        *Not supported by limited Registries.*

    .. py:method:: addQuantum(quantum)

        Add a new :ref:`Quantum` to the :ref:`Registry`.

        :param Quantum quantum: a :py:class:`Quantum` instance to add to the :ref:`Registry`.

        .. todo::

            How do we label/identify Quanta, and associate their Python objects with database records?

    .. py:method:: addDataUnit(unit, replace=False)

        Add a new :ref:`DataUnit`, optionally replacing an existing one (for updates).

        :param DataUnit unit: the :py:class:`DataUnit` to add or replace.

        :param bool replace: if True, replace any matching :ref:`DataUnit` that already exists (updating its non-unique fields) instead of raising an exception.

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

    .. py:method:: makeDataGraph(tag, expr, datasetTypes) -> DataGraph

        Evaluate a filter expression and a list of :ref:`DatasetTypes <DatasetType>` and return a :ref:`DataGraph`.

        :param str tag: a :ref:`CollectionTag <Collection>` indicating the :ref:`Collection` to search.

        :param str expr: an expression that limits the :ref:`DataUnits <DataUnit>` and (indirectly) the :ref:`Datasets <Dataset>` returned.

        :param list[DatasetType] datasetTypes: the list of :ref:`DatasetTypes <DatasetType>` whose instances should be included in the graph.

        .. todo::

            More complete description for expressions.

        :returns: a :ref:`DataGraph` instance

        *Not supported by limited Registries.*

    .. py:method:: subset(tag, expr, datasetTypes)

        Create a new :ref:`Collection` by subsetting an existing one.

        :param str tag: a :ref:`CollectionTag <Collection>` indicating the input :ref:`Collection` to subset.

        :param str expr: an expression that limits the :ref:`DataUnits <DataUnit>` and (indirectly) the :ref:`Datasets <Dataset>` in the subset.

        :param list[DatasetType] datasetTypes: the list of :ref:`DatasetTypes <DatasetType>` whose instances should be included in the subset.

        :returns: a str :ref:`CollectionTag <Collection>`

        *Not supported by limited Registries.*

    .. py:method:: merge(outputTag, inputTags)

        Create a new :ref:`Collection` from a series of existing ones.

        Entries earlier in the list will be used in preference to later entries when both contain :ref:`Datasets <Dataset>` with the same :ref:`DatasetRef`.

        :param outputTag: a str :ref:`CollectionTag <Collection>` to use for the new :ref:`Collection`.

        :param list[str] inputTags: a list of :ref:`CollectionTags <Collection>` to combine.

        *Not supported by limited Registries.*

    .. py:method:: export(tag) -> str

        Export contents of :ref:`Registry` for a given :ref:`CollectionTag <Collection>` in a text
        format that can be imported into a different database.

        :param str tag: a :ref:`CollectionTag <Collection>` indicating the input :ref:`Collection` to export.

        :returns: a str containing a serialized form of the subset of the :ref:`Registry`.

        .. todo::
            This may not be the most efficient way of doing things.
            But we should provide some generic way of transporting collections between databases.
            Maybe we should also support exporting more than one at a time?

        *Not supported by limited Registries.*

    .. py:method:: import(serialized)

        Import (previously exported) contents into the (possibly empty) :ref:`Registry`.

        :param str serialized: a str containing a serialized form of a subset of a :ref:`Registry`.

        *Limited Registries will import only some of the information exported by full Registry.*


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

