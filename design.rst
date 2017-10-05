########
Overview
########

The data access system deals primarily with the storage, retrieval and querying of
:ref:`Datasets <Dataset>`.  An example of such a :ref:`Dataset` could be a 
calibrated exposure (``calexp``) for a particular instrument corresponding to a
particular visit and sensor, produced by a particular processing run.

These :ref:`Datasets <Dataset>` form both the input and output of units of work called
:ref:`Quanta <Quantum>`, and the data access system is also responsible for tracking the relations
between them.

The in-memory manifestation of a :ref:`Dataset` (e.g. as a Python object) is called a
:ref:`ConcreteDataset`.  The :ref:`Butler` is the user-facing interface employed to
load, store, and query :ref:`ConcreteDatasets <ConcreteDataset>` and their relations.

Relations between :ref:`Datasets <Dataset>`, :ref:`Quanta <Quantum>`, and locations
for stored objects are kept in a SQL database which implements the :ref:`Common Schema <CommonSchema>`.
The :ref:`Registry` class provides an interface to such a database.

In the database, the :ref:`Datasets <Dataset>` are grouped into :ref:`Collections <Collection>`,
which are identified by a :ref:`CollectionTag`.
Within a given :ref:`Collection` a :ref:`Dataset` is uniquely identified by a :ref:`DatasetRef`.

Conceptually a :ref:`DatasetRef` is a combination of a :ref:`DatasetType` (e.g. ``calexp``)
and a set of :ref:`DataUnits <DataUnit>`.  A :ref:`DataUnit` is a discrete unit of
data (e.g. a particular visit, tract, or filter).

A :ref:`DatasetRef` is thus a label that refers to different-but-related :ref:`Datasets <Dataset>`
in different :ref:`Collections <Collection>`. An example is a ``calexp`` for a particular visit
and CCD produced in different processing runs (with each processing run thus being a :ref:`Collection`).

Storing the :ref:`Datasets <Dataset>` themselves, as opposed to information about them, is the
responsibility of the :ref:`Datastore`.

An overview of the framework structure can be seen in the following figure:

.. _framework_structure:

.. image:: images/concepts.png
    :scale: 75%

Users primarily interact with a particular :ref:`Butler` instance that
**provides access to a single** :ref:`Collection`.

They can use this instance to:

* Load a :ref:`Dataset` associated with a particular :ref:`DatasetRef`,
* Store a :ref:`Dataset` associated with a particular :ref:`DatasetRef`, and
* Obtain a :ref:`DataGraph`, which is a related set of :ref:`DatasetRefs <DatasetRef>` and
  :ref:`DataUnits <DataUnit>` corresponding to a (limited) SQL query.

The :ref:`Butler` implements these requests by holding a **single instance** of :ref:`Registry`
and **a single instance** of :ref:`Datastore`, to which it delegates the calls (note, however,
that this :ref:`Datastore` may delegate to one or more other :ref:`Datastores <Datastore>`).

These components constitute a separation of concerns:

* :ref:`Registry` has no knowledge of how :ref:`Datasets <Dataset>` are actually stored, and
* :ref:`Datastore` has no knowledge of how :ref:`Datasets <Dataset>` are related and their scientific meaning (i.e. knows nothing about :ref:`Collections <Collection>`, :ref:`DataUnits <DataUnit>` and :ref:`DatasetRefs <DatasetRef>`).

This separation of concerns is a key feature of the design and allows for different
implementations (or backends) to be easily swapped out, potentially even at runtime.

Communication between the components is mediated by the:

* :ref:`URI` that records **where** a :ref:`Dataset` is stored, and the
* :ref:`DatasetMetatype` that holds information about **how** a :ref:`Dataset` can be stored.

The :ref:`Registry` is responsible for providing the :ref:`DatasetMetatype` for
stored :ref:`Datasets <Dataset>` and the :ref:`Datastore` is responsible
for providing the :ref:`URI` from where it can be subsequently retrieved.

.. note::

    Both the :ref:`Registry` and the :ref:`Datastore` typically each
    come as a client/server pair.  In some cases the server part may be a direct backend,
    such as a SQL server or a filesystem, that does not require any custom software daemon (other than e.g. a third-party database or http server).
    In some cases, such as when server-side subsetting of a :ref:`Dataset` is needed, a daemon for at least the :ref:`Datastore` will be required.

##########
Operations
##########

.. _basic_io:

Basic IO
========

To see how the various components interact we first examine a basic ``get`` and ``put`` operations for the basic case of a non-composite :ref:`Dataset`.
We assume that the :ref:`Butler` is configured with an external :ref:`Registry` and :ref:`Datastore`, both consisting of a client-server pair.

Basic ``get``
-------------

The user has a :ref:`DatasetRef`, constructed or obtained by a query and wishes to retrieve the associated :ref:`ConcreteDataset`.

This proceeds allong the following steps:

1. User calls: ``butler.get(datasetRef)``.
2. :ref:`Butler` forwards this call to its :ref:`Registry`, adding the :ref:`CollectionTag` it was configured with (i.e. ``butler.registry.find(butler.config.collectionTag, datasetRef)``).
3. :ref:`Registry` performs the lookup on the server using SQL and returns the :ref:`URI` and the :ref:`DatasetMetatype` of the stored :ref:`Dataset`.
4. :ref:`Butler` forwards the request, with both the :ref:`URI` and the :ref:`DatasetMetatype`, to the :ref:`Datastore` client (i.e. ``butler.datastore.get(uri, datasetMetatype)``).
5. :ref:`Datastore` client requests a serialized version of the :ref:`Dataset` from the server using the :ref:`URI`.
6. Using the :ref:`DatasetMetatype`, to determine the appropriate deserialization function, the :ref:`Datastore` client then materializes the :ref:`ConcreteDataset` and returns it to the :ref:`Butler`.
7. :ref:`Butler` then returns the :ref:`ConcreteDataset` to the user.

See :py:meth:`the API documentation <Butler.get>` for more information.

.. note::

    The :ref:`Datastore` request can be a simple ``HTTP GET`` request for a stored FITS file, or something more complicated.
    In the former case the materialization would be a simple FITS read (e.g. of a ``calexp``), with the reader determined by the :ref:`DatasetMetatype` retrieved from the :ref:`Registry`.

.. note::

    The serialized version sent over the wire doesn't have to correspond to the format stored on disk in the :ref:`Datastore` server.  As long as it is serialized in the form expected by the client.

Basic ``put``
-------------

The user has a :ref:`ConcreteDataset` and wishes to store this at a particular :ref:`DatasetRef`.

This proceeds allong the following steps:

1. User calls: ``butler.put(datasetRef, concreteDataset)``.
2. :ref:`Butler` first obtains the correct :ref:`DatasetMetatype` from the :ref:`Registry` by calling ``butler.registry.getDatasetMetatype(butler.config.collectionTag, datasetRef)``.
3. :ref:`Butler` obtains a :ref:`Path` from the :ref:`Registry` by calling ``butler.registry.makePath(butler.config.collectionTag, datasetRef)``. This path is a hint to be used by the :ref:`Datastore` to decide where to store it.
4. :ref:`Butler` then asks the :ref:`Datastore` client to store the file by calling: ``butler.datastore.put(concreteDataset, datasetMetatype, path)``.
5. The :ref:`Datastore` client then uses the serialization function associated with the :ref:`DatasetMetatype` to serialize the :ref:`ConcreteDataset` and sends it to the :ref:`Datastore` server.
   Depending on the type of server it may get back the actual :ref:`URI` or the client can generate it itself.
6. :ref:`Datastore` returns the actual :ref:`URI` to the :ref:`Butler`.
7. :ref:`Butler` calls the :ref:`Registry` function ``addDataset`` to add the :ref:`Dataset` to the collection.
8. :ref:`Butler` returns the :ref:`URI` to the user.

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

The ``registry.find()`` call therefore not only returns the :ref:`URI` and :ref:`DatasetMetatype` of the **parent** (associated with the :ref:`DatasetRef`), but also a `DatasetComponents` dictionary of ``name : DatasetRef`` specifying its **children**.

The :ref:`Butler` retrieves **all** :ref:`Datasets <Dataset>` from the :ref:`Datastore` as :ref:`ConcreteDatasets <ConcreteDataset>` and then calls the ``assemble`` function associated with the :ref:`DatasetMetatype` of the primary to create the final composed :ref:`ConcreteDataset`.

This process is most easily understood by reading the API documentation for :py:meth:`butler.get <Butler.get>` and :py:meth:`butler.put <Butler.put>`.

#########
Reference
#########

.. _Dataset:

Dataset
=======

A Dataset is a discrete entity of stored data, possibly with associated metadata.

Datasets are uniquely identified by either a :ref:`URI` or the combination of a :ref:`CollectionTag` and a :ref:`DatasetRef`.

A Dataset may be *composite*, which means it contains one or more named *component* Datasets.

Example: a "calexp" for a single visit and sensor produced by a processing run.

Transition
----------

The Dataset concept has essentially the same meaning that it did in the v14 Butler.

A Dataset is analogous to an Open Provenance Model "artifact".

Python API
----------

The Python representation of a :ref:`Dataset` is in some sense a :ref:`ConcreteDataset`, and hence we have no Python "Dataset" class.

But the equivalent to the complete SQL representation of a Dataset in the :ref:`CommonSchema` is a useful data structure in Python: the :py:class:`DatasetHandle` class.

.. py:class:: DatasetHandle(DatasetRef)

    A concrete, final class whose instances represent :ref:`Datasets <Dataset>`.

    DatasetHandle inherits from :py:class:`DatasetRef`, and can be used in any context where a :py:class:`DatasetRef` is expected.

    DatasetHandle instances are immutable.

    DatasetHandle instances always correspond to :ref:`Datasets <Dataset>` that have already been stored.
    The only way to obtain a DatasetHandle instance is the :py:class:`Registry` interface.
    :py:class:`DatasetRef` instances, in contrast, can be directly constructed without a :py:class:`Registry` and can refer to :ref:`Datasets <Dataset>` that have not yet been created.

    .. py:attribute:: uri

        Read-only instance attribute.

        The :ref:`URI` that holds the location of the :ref:`Dataset` in a :ref:`Datastore`.

    .. py:attribute:: components

        Read-only instance attribute.

        A :py:class:`dict` holding :py:class:`DatasetHandle` instances that correspond to this :ref:`Dataset's <Dataset>` named components.

        Empty (or None?) if the :ref:`Dataset` is not a composite.


SQL Representation
------------------

.. todo::

    Fill in how Datasets are represented in SQL.


.. _DatasetRef:

DatasetRef
==========

An identifier for a :ref:`Dataset` that can be used across different :ref:`Collections <Collection>` and :ref:`Registries <Registry>`.
A :ref:`DatasetRef` is effectively the combination of a :ref:`DatasetType` and a tuple of :ref:`DataUnits <DataUnit>`.

Transition
----------

The v14 Butler's DataRef class played a similar role.

Python API
----------

.. py:class:: DatasetRef

    A concrete non-final class whose instances are :ref:`DatasetRefs <DatasetRef>`.

    DatasetRefs are immutable.

    The target of a DatasetRef may or may not exist, making it appropriate for to-be-created :ref:`Datasets <Dataset>`.

.. py:class:: DatasetHandle

    Inherits from DatasetRef, and represents a :ref:`Dataset` that is known to exist.

    .. py:attribute:: units

        A tuple (or ``frozenset``?) of :py:class:`DataUnit` instances that label the :ref:`DatasetRef` within a :ref:`Collection`.

    .. py:attribute:: type

        The :py:class:`DatasetType` associated with the :ref:`Dataset` the :ref:`DatasetRef` points to.


SQL Representation
------------------

.. todo::

    Fill in SQL interface


.. _DatasetType:

DatasetType
===========

A named category of :ref:`Datasets <Dataset>` that defines how they are organized, related, and stored.

In addition to a name, a DatasetType includes:

 - a template string that can be used to construct a :ref:`Path`;
 - a tuple of :ref:`DataUnitTypes <DataUnitType>` that define the structure of :ref:`DatasetRefs <DatasetRef>`;
 - a :ref:`DatasetMetatype` that determines how :ref:`Datasets <Dataset>` are stored and composed.

Transition
----------

The DatasetType concept has essentially the same meaning that it did in the v14 Butler.

Python API
----------

.. py:class:: DatasetType

    A concrete, final class whose instances represent :ref:`DatasetTypes <DatasetType>`.

    DatasetType instances may be constructed without a :ref:`Registry`, but they must be registered via :py:meth:`Registry.registerDatasetType` before corresponding :ref:`Datasets <Dataset>` may be added.

    DatasetType instances are immutable.

    .. note::

        In the current design, :py:class:`DatasetTypes <DatasetType>` are not type objects, and the :py:class:`DatasetRef` class is not an instance of :py:class:`DatasetType`.
        We could make that the case with a lot of metaprogramming, but this adds a lot of complexity to the code with no obvious benefit.
        It seems most prudent to just rename the :ref:`DatasetType` concept and class to something that doesn't imply a type-instance relationship in Python.

    .. py:method:: __init__(name, template, units, meta)

        Public constructor.  All arguments correspond directly to instance attributes.

    .. py:attribute:: name

        Read-only instance attribute.

        A string name for the :ref:`Dataset`; must be unique within a :ref:`Registry`.

        .. todo::

            Could/should we make this unique within a :ref:`Collection` instead?

    .. py:attribute:: template

        Read-only instance attribute.

        A string with ``str.format``-style replacement patterns that can be used to create a :ref:`Path` from a :ref:`CollectionTag` and a :ref:`DatasetRef`.

    .. py:attribute:: units

        Read-only instance attribute.

        A tuple of :py:class:`DataUnit` subclasses (not instances) that define the :ref:`DatasetRef <DatasetRef>` corresponding to this :ref:`DatasetType`.

    .. py:attribute:: meta

        Read-only instance attribute.

        A :py:class:`DatasetMetatype` subclass (not instance) that defines how this :ref:`DatasetType` is persisted.

SQL Representation
------------------

.. todo::

    Fill in SQL interface


.. _ConcreteDataset:

ConcreteDataset
===============

The in-memory manifestation of a :ref:`Dataset`

Example: an ``afw.image.Exposure`` instance with the contents of a particular ``calexp``.

Transition
----------

The "python" and "persistable" entries in v14 Butler dataset policy files refer to Python and C++ ConcreteDataset types, respectively.

Python API
----------

While all ConcreteDatasets are Python objects, they have no common class or interface.

SQL Representation
------------------

ConcreteDatasets exist only in Python and do not have any SQL representation.


.. _DataUnit:

DataUnit
========

A discrete abstract unit of data that can be associated with metadata or used to label a :ref:`Dataset`.

Examples: individual Visits, Tracts, or Filters.


Transition
----------

The string keys of data ID dictionaries passed to the v14 Butler are similar to DataUnits.

Python API
----------

.. py:class:: DataUnit

    An abstract base class whose subclasses represent concrete :ref:`DataUnits <DataUnit>`.

    .. py:attribute:: id

        Read-only pure-virtual instance attribute (must be implemented by subclasses).

        An integer that fully identifies the :ref:`DataUnit` instance, and is used as the primary key in the :ref:`CommonSchema` table for that :ref:`DataUnit`.

    .. py:attribute:: value

        Read-only pure-virtual instance attribute (must be implemented by subclasses).

        An integer or string that identifies the :ref:`DataUnit` when combined with any "foreign key" connections to other :ref:`DataUnits <DataUnit>`.
        For example, a Visit's number is its value, because it uniquely labels a Visit as long as its Camera (its only foreign key :ref:`DataUnit`) is also specified.

        .. todo::

            Rephrase the above to make it more clear and preferably avoid using the phrase "foreign key", as that's a SQL concept that doesn't have an obvious meaning in Python.
            We may need to have a Python way to expose the connections to other DataUnits on which a DataUnit's value.

.. todo::

    Where should we document the concrete DataUnit classes?
    They're closely related to common schema tables, but the Python API can't be inferred directly from the SQL declarations (and vice versa).


SQL Representation
------------------

A :ref:`DataUnit` is a row in the table for its :ref:`DataUnitType`.

:ref:`DataUnits <DataUnit>` must be shared across different :ref:`Registries <Registry>` , so their primary keys must not be database-specific quantities such as autoincrement fields.

.. todo::

    Add links once Common Schema has link anchors for different tables.


.. _DataUnitType:

DataUnitType
============

The conceptual type of a :ref:`DataUnit`, which defines what relationships it has with other DataUnitTypes and the fields of any metadata associated with it.

Examples: Visit, Tract, or Filter

Transition
----------

The DataUnitType concept does not exist in the v14 Butler.

Python API
----------

A DataUnitType is represented by a concrete :py:class:`DataUnit` subclass (the type object, not an instance thereof).

SQL Representation
------------------

Each :ref:`DataUnitType` is a table that the holds :ref:`DataUnits <DataUnit>` of that type as its rows.

.. todo::

    Add links once Common Schema has link anchors for different tables.


.. _Collection:

Collection
==========

An entity that contains :ref:`Datasets <Dataset>`, with the following conditions:

- Has at most one :ref:`Dataset` per :ref:`DatasetRef`.
- Has a unique, human-readable identifier (i.e. :ref:`CollectionTag`).
- Can be used to obtain a globally (across Collections) unique :ref:`URI` given a :ref:`DatasetRef`.

Transition
----------

The v14 Butler's Data Repository concept plays a similar role in many contexts, but with a very different implementation and a very different relationship to the :ref:`Registry` concept.

Python API
----------

There is no direct Python representation of a Collection.


SQL Representation
------------------

.. todo::

    Fill in SQL interface


.. _CollectionTag:

CollectionTag
=============

A unique identifier of a :ref:`Collection` within a :ref:`Registry`.

.. note::

  That such tags need to be storable in a :ref:`ButlerConfiguration` file.

Transition
----------

A path to a directory containing a v14 Butler Data Repository played a similar role.

Python API
----------

A CollectionTag can probably be implemented as a simple string in Python.

SQL Representation
------------------

.. todo::

    Fill in SQL interface


.. _Quantum:

Quantum
=======

A discrete unit of work that may depend on one or more :ref:`Datasets <Dataset>` and produces one or more :ref:`Datasets <Dataset>`.

Most Quanta will be executions of a particular SuperTask's ``runQuantum`` method, but they can also be used to represent discrete units of work performed manually by human operators or other software agents.

Transition
----------

The Quantum concept does not exist in the v14 Butler.

A Quantum is analogous to an Open Provenance Model "process".

Python API
----------

.. py:class:: Quantum

    .. py:attribute:: predictedInputs

        A dictionary of input datasets that were expected to be used, with :ref:`DatasetType` names as keys and a :py:class:`set` of :py:class:`DatasetRef` instances as values.

        Input :ref:`Datasets <Dataset>` that have already been stored may be :py:class:`DatasetHandles <DatasetHandle>`, and in many contexts may be guaranteed to be.

    .. py:attribute:: actualInputs

        A dictionary of input datasets that were actually used, with the same form as :py:attr:`predictedInputs`.

        All returned sets must be subsets of those in :py:attr:`predictedInputs`.

    .. py:attribute:: outputs

        A dictionary of output datasets, with the same form as :py:attr:`predictedInputs`.

    .. py:attribute:: task

        If the Quantum is associated with a SuperTask, this is the SuperTask instance that produced and should execute this set of inputs and outputs.
        If not, a str identifier for the operation.  May also be None.

SQL Representation
------------------

.. todo::

    Fill in SQL interface



.. _DatasetExpression:

DatasetExpression
=================

An expression forming part of a SQL query that can be evaluated to yield one or more unique :ref:`DatasetRefs <DatasetRef>` and their relations (in a :ref:`DataGraph`).

.. todo::

    An open question is if it is sufficient to only allow users to vary the ``WHERE`` clause of the SQL query, or if custom joins are also required.

Transition
----------

DatasetExpressions replace the command-line argument syntax used to specifiy data IDs to ``CmdLineTasks`` in the v14 stack.

Python API
----------

A DatasetExpression is just a ``str``.

SQL Representation
------------------

.. todo::

    Fill in SQL interface



.. _DataGraph:

DataGraph
=========

A graph in which the nodes are :ref:`DatasetRefs <DatasetRef>` and :ref:`DataUnits <DataUnit>`, and the edges are the relations between them.

Transition
----------

No similar concept exists in the v14 Butler.

Python API
----------

.. todo::

    Link to SuperTask docs, or move the authoritative description here.


SQL Representation
------------------

.. todo::

    Fill in SQL interface


.. _QuantumGraph:

QuantumGraph
============

A directed acyclic graph in which the nodes are :ref:`Datasets <Dataset>` and :ref:`Quanta <Quantum>`, and the edges are the relations between them.
This can be used to describe the to-be-executed processing defined by SuperTask preflight, or the provenance of already-produced :ref:`Datasets <Dataset>`.

Transition
----------

No similar concept exists in the v14 Butler.

Python API
----------

.. todo::

    Link to SuperTask docs, or move the authoritative description here.


SQL Representation
------------------

.. todo::

    Fill in SQL interface


.. _URI:

URI
===

A standard Uniform Resource Identifier pointing to a :ref:`ConcreteDataset` in a :ref:`Datastore`.

The :ref:`Dataset` pointed to may be **primary** or a component of a **composite**, but should always be serializable on its own.
When supported by the :ref:`Datastore` the query part of the URI (i.e. the part behind the optional question mark) may be used for continuous subsets (e.g. a region in an image).

Transition
----------

No similar concept exists in the v14 Butler.

Python API
----------

We can probably assume a URI will be represented as a simple string initially.

It may be useful to create a class type to enforce grammar and/or provide convenience operations in the future.


SQL Representation
------------------

URIs are stored as a field in the Dataset table.

.. todo::

    Add links when anchors for tables are present.


.. _Path:

Path
====

The part of a :ref:`URI` that refers to a location **within** a :ref:`Datastore`

Typically provided as a hint to the :ref:`Datastore` to suggest a storage location/naming.
The actual :ref:`URI` used for storage is not required to respect the hint (e.g. for object stores).

Transition
----------

No similar concept exists in the v14 Butler.

Python API
----------

Paths are represented by simple Python strings.

SQL Representation
------------------

Paths do not appear in SQL at all.



.. _DatasetMetatype:

DatasetMetatype
===============

A category of :ref:`DatasetTypes <DatasetType>` that utilize the same in-memory classes for their :ref:`ConcreteDatasets <ConcreteDataset>` and can be saved to the same file format(s).


Transition
----------

The allowed values for "storage" entries in v14 Butler policy files are analogous to DatasetMetatypes.

Python API
----------

.. py:class:: DatasetMetatype

    An abstract base class whose subclasses are :ref:`DatasetMetatypes <DatasetMetatype>`.

    .. py:attribute:: subclasses

        Concrete class attribute: provided by the base class.

        A dictionary holding all :py:class:`DatasetMetatype` subclasses,
        keyed by their :py:attr:`name` attributes.

    .. py:attribute:: name

        Virtual class attribute: must be provided by derived classes.

        A string name that uniquely identifies the derived class.

    .. py:attribute:: components

        Virtual class attribute: must be provided by derived classes.

        A dictionary that maps component names to the :py:class:`DatasetMetatype` subclasses for those components.
        Should be empty (or ``None``?) if the :ref:`DatasetMetatype` is not a composite.

    .. py:method:: assemble(parent, components, parameters=None)

        Assemble a compound :ref:`ConcreteDataset`.

        Virtual method: must be implemented by derived classes.

        :param parent:
            An instance of the compound :ref:`ConcreteDataset` to be returned, or None.
            If no components are provided, this is the :ref:`ConcreteDataset` that will be returned.

        :param dict components: A dictionary whose keys are a subset of the keys in the :py:attr:`components` class attribute and whose values are instances of the component ConcreteDataset type.

        :param dict parameters: details TBD; may be used for parameterized subsets of :ref:`Datasets <Dataset>`.

        :return: a :ref:`ConcreteDataset` matching ``parent`` with components replaced by those in ``components``.

SQL Representation
------------------

The DatasetType table holds DatasetMetatype names in a ``varchar`` field.
As a name is sufficient to retreive the rest of the DatasetMetatype definition in Python, the additional information is not duplicated in SQL.

.. todo::

    Add links when anchors for tables are present.


.. _Registry:

Registry
========

A database that holds metadata, relationships, and provenance for managed :ref:`Datasets <Dataset>`.

A registry is typically a SQL database (e.g. `PostgreSQL`, `MySQL` or `SQLite`) that provides a
realization of the :ref:`Common Schema <CommonSchema>`.

In some important contexts (e.g. processing data staged to scratch space), only a small subset of the full Registry interface is needed, and we may be able to utilize a simple key-value database instead.

Many Registry implementations will consist of both a client and a server (though the server will frequently be just a database server with no additional code).

Transition
----------

The v14 Butler's Mapper class contains a Registry object that is also implemented as a SQL database, but the new Registry concept differs in several important ways:

 - new Registries can hold multiple Collections, instead of being identified strictly with a single Data Repository;
 - new Registries also assume some of the responsibilities of the v14 Butler's Mapper;
 - new Registries have a much richer set of tables, permitting many more types of queries.

Python API
----------

.. py:class:: Registry

    .. py:method:: registerDatasetType(tag, datasetType)

        Add a new :ref:`DatasetType` to a :ref:`Collection`.
        If the :ref:`DatasetType` already exists, it will be associated with the given :ref:`Collection`.

        :param str tag: a :ref:`CollectionTag` indicating the :ref:`Collection` the :ref:`DatasetType` should be associated with.

        :param DatasetType datasetType: the :ref:`DatasetType` to be added

        :return: None

    .. py:method:: addDataset(tag, ref, uri, components, quantum=None)

        Add a :ref:`Dataset` to a :ref:`Collection`.

        This always adds a new :ref:`Dataset`; to associate an existing :ref:`Dataset` with a new :ref:`Collection`, use :py:meth:`associate`.

        The :ref:`Quantum` that generated the :ref:`Dataset` can optionally be provided to add provenance information.

        :param str tag: a :ref:`CollectionTag` indicating the Collection the :ref:`DatasetType` should be associated with.

        :param DatasetRef ref: a :ref:`DatasetRef` that identifies the :ref:`Dataset` and contains its :ref:`DatasetType`.

        :param str uri: the :ref:`URI` that has been associated with the :ref:`Dataset` by a :ref:`Datastore`.

        :param dict components: if the :ref:`Dataset` is a composite, a ``{name : URI}`` dictionary of its named components and storage locations.

        :return: a newly-created :py:class:`DatasetHandle` instance.

        :raises: an exception if a :ref:`Dataset` with the given :ref:`DatasetRef` already exists in the given :ref:`Collection`.

    .. py:method:: associate(tag, handle)

        Add an existing :ref:`Dataset` to an existing :ref:`Collection`.

        :param str tag: a :ref:`CollectionTag` indicating the Collection the :ref:`DatasetType` should be associated with.

        :param DatasetHandle handle: a :py:class:`DatasetHandle` instance that already exists in another :ref:`Collection` in this :ref:`Registry`.

        :return: None

    .. py:method:: addQuantum(quantum)

        Add a new :ref:`Quantum` to the :ref:`Registry`.

        :param Quantum quantum: a :py:class:`Quantum` instance to add to the :ref:`Registry`.

        .. todo::

            How do we label/identify Quanta, and associate their Python objects with database records?

    .. py:method:: addDataUnit(unit, replace=False)

        Add a new :ref:`DataUnit`, optionally replacing an existing one (for updates).

        :param DataUnit unit: the :py:class:`DataUnit` to add or replace.

        :param bool replace: if True, replace any matching :ref:`DataUnit` that already exists (updating its non-unique fields) instead of raising an exception.

    .. py:method:: find(tag, ref)

        Look up the location of the :ref:`Dataset` associated with the given `DatasetRef`.

        This can be used to obtain the :ref:`URI` that permits the :ref:`Dataset` from a :ref:`Datastore`.

        :param str tag: a :ref:`CollectionTag` indicating the :ref:`Collection` to search.

        :param DatasetRef ref: a :ref:`DatasetRef` that identifies the :ref:`Dataset`.

        :returns: a :py:class:`DatasetHandle` instance

        .. todo::

            I've changed this to return a :py:class:`DatasetHandle`, since that aggregates the things we need it to return.
            It also provides a way to get a :py:class:`DatasetHandle` instance for an existing :ref:`Dataset`.
            But now we need to update any operations and code snippets that use the old interface.
            We also can't use this to get the :ref:`DatasetMetatype` from a :ref:`DatasetRef`, but that's okay, because we should be able to get that directly from the :py:class:`DatasetRef` itself.

    .. py:method:: makeDataGraph(tag, expr, datasetTypes) -> DataGraph

        Evaluate a :ref:`DatasetExpression` given a list of :ref:`DatasetTypes <DatasetType>` and return a :ref:`DataGraph`.

        :param str tag: a :ref:`CollectionTag` indicating the :ref:`Collection` to search.

        :param str expr: a :ref:`DatasetExpression` that limits the :ref:`DataUnits <DataUnit>` and (indirectly) the :ref:`Datasets <Dataset>` returned.

        :param list[DatasetType] datasetTypes: the list of :ref:`DatasetTypes <DatasetType>` whose instances should be included in the graph.

        .. todo::
            Should we also supply a ``findAll`` or something to give you just a list
            of :ref:`Datasets <Dataset>`?  Or should the :ref:`DataGraph` be iterable
            (I guess it already is) such that one can loop over the results of a query
            and retrieve all relevant :ref:`Datasets <Dataset>`?

        :returns: a :ref:`DataGraph` instance

    .. py:method:: makePath(tag, ref) -> Path

        Construct the `Path` part of a :ref:`URI`. This is often just a storage hint since the
        :ref:`Datastore` will likely have to deviate from the provided path
        (in the case of an object-store for instance).

        Although a :ref:`Dataset` may belong to multiple :ref:`Collections <Collection>`, only the first :ref:`Collection` it is added to is used in its :ref:`Path`.

        :param str tag: a :ref:`CollectionTag` indicating the :ref:`Collection` to which the :ref:`Dataset` will be added.

        :param DatasetRef ref: a :py:class:`DatasetRef` instance that holds the :ref:`DataUnits <DataUnit>` whose values will be inserted into a template to form the :ref:`Path`.

        :returns: a str :ref:`Path`

        .. todo:
            This doesn't require a database lookup if DatasetRef has a DatasetType, and DatasetType has a template.
            Should we move it to DatasetRef instead?

    .. py:method:: subset(tag, expr, datasetTypes)

        Create a new :ref:`Collection` by subsetting an existing one.

        :param str tag: a :ref:`CollectionTag` indicating the input :ref:`Collection` to subset.

        :param str expr: a :ref:`DatasetExpression` that limits the :ref:`DataUnits <DataUnit>` and (indirectly) the :ref:`Datasets <Dataset>` in the subset.

        :param list[DatasetType] datasetTypes: the list of :ref:`DatasetTypes <DatasetType>` whose instances should be included in the subset.

        :returns: a str :ref:`CollectionTag`

    .. py:method:: merge(outputTag, inputTags)

        Create a new :ref:`Collection` from a series of existing ones.

        Entries earlier in the list will be used in preference to later entries when both contain :ref:`Datasets <Dataset>` with the same :ref:`DatasetRef`.

        :param outputTag: a str :ref:`CollectionTag` to use for the new :ref:`Collection`.

        :param list[str] inputTags: a list of :ref:`CollectionTags <CollectionTag>` to combine.

    .. py:method:: export(tag) -> str

        Export contents of :ref:`Registry` for a given :ref:`CollectionTag` in a text
        format that can be imported into a different database.

        :param str tag: a :ref:`CollectionTag` indicating the input :ref:`Collection` to export.

        :returns: a str containing a serialized form of the subset of the :ref:`Registry`.

        .. todo::
            This may not be the most efficient way of doing things.
            But we should provide some generic way of transporting collections between databases.
            Maybe we should also support exporting more than one at a time?

    .. py:method:: import(serialized)

        Import (previously exported) contents into the (possibly empty) :ref:`Registry`.

        :param str serialized: a str containing a serialized form of a subset of a :ref:`Registry`.


SQL Representation
------------------

A Registry provides an interface for queryingt the :ref:`CommonSchema`, and hence has no representation within that schema.


.. _Datastore:

Datastore
=========

A system that holds persisted :ref:`Datasets <Dataset>` and can read and optionally write them.

This may be based on a (shared) filesystem, an object store or some other system.

Many Datastore implementations will consist of both a client and a server.

Transition
----------

Datastore represents a refactoring of some responsibilities previously held by the v14 Butler and Mapper objects.

Python API
----------

.. py:class:: Datastore

    .. py:method:: get(uri, parameters=None) -> ConcreteDataset

        Load a :ref:`ConcreteDataset` from the store.
        Optional ``parameters`` may specify things like regions.

    .. py:method:: put(ConcreteDataset, DatasetMetatype, Path) -> URI, {name : URI}

        Write a :ref:`ConcreteDataset` with a given :ref:`DatasetMetatype` to the store.
        The :ref:`DatasetMetatype` is used to determine the serialization format.
        The ``Path`` is a storage hint.  The actual ``URI`` of the stored :ref:`Dataset` is returned as are the possible components.

        .. note::
            This is needed because some :ref:`datastores <Datastore>` may need to modify the :ref:`URI`.
            Such is the case for object stores (which can return a hash) for instance.

    .. py:method:: retrieve({URI (from) : URI (to)}) -> None

        Retrieves :ref:`Datasets <Dataset>` and stores them in the provided locations.
        Does not have to go through the process of creating a :ref:`ConcreteDataset`.

        .. todo::
            How does this handle composites?

SQL Representation
------------------

Datastores are not represented in SQL at all.


.. _ButlerConfiguration:

ButlerConfiguration
===================

Configuration for :ref:`Butler`.

.. py:class:: ButlerConfiguration

    .. py:attribute:: inputCollection

        The :ref:`CollectionTag` of the input collection.

    .. py:attribute:: outputCollection

        The :ref:`CollectionTag` of the output collection.


.. _Butler:

Butler
======

A high level object that provides access to the :ref:`Datasets <Dataset>` in a single :ref:`Collection`.


Transition
----------

The new Butler plays essentially the same role as the v14 Butler.

Python API
----------

Butler is a concrete, final Python class in the current design; all extensibility is provided by the :ref:`Registry` and :ref:`Datastore` instances it holds.

.. py:class:: Butler

    .. py:attribute:: config

        a :py:class:`ButlerConfiguration` instance

    .. py:attribute:: datastore

        a :py:class:`Datastore` instance

    .. py:attribute:: registry

        a :py:class:`Registry` instance

    .. py:method:: get(DatasetRef, parameters=None) -> ConcreteDataset

        Implemented as:

        .. code:: python

            try:
                uri, datasetMetatype, datasetComponents = RDB.find(self.config.inputCollection, datasetRef)
                parent = RDS.get(uri, datasetMetatype, parameters) if uri else None
                # Recurse to obtain child components
                children = {name : self.get(childDatasetRef, parameters) for name, childDatasetRef in datasetComponents.items()}
                return datasetMetatype.assemble(parent, children, parameters)
            except NotFoundError:
                continue
            raise NotFoundError("DatasetRef {} not found in any input collection".format(datasetRef))

    .. py:method:: put(DatasetRef, ConcreteDataset, Quantum) -> None

        Implemented as:

        .. code:: python

            datasetMetatype = RDB.getDatasetMetatype(self.config.outputCollection, datasetRef)
            path = RDB.makePath(self.config.outputCollection, datasetRef)
            uri, datasetComponents = RDS.put(concreteDataset, datasetMetatype, path)
            RDB.addDataset(self.config.outputCollection, datasetRef, uri, datasetComponents, quantum)

        .. todo::

            Given the similarity in output, we could just use ``find`` to obtain the :ref:`URI` and
            :ref:`DatasetMetatype` for things that don't yet exist.
            Then we don't need ``makePath`` (and possibly ``getDatasetMetatype``) anymore, which
            would be cleaner IMHO (I don't like ``makePath`` much, it feels like too much internal exposure).

SQL Representation
------------------

Butler provides a limited interface for executing SQL queries against the :ref:`Registry` it holds, and hence does not have any SQL representation itself.

.. _CommonSchema:

######
Schema
######

.. warning::

    This section is out of date.  The ``common-schema-dev/db_full.sql`` file
    in the source repository for this technote currently contains the
    authoritative description of the commmon schema.


The Common Schema is a set of conceptual SQL tables (which may be implemented as views) that can be used to retrieve :ref:`DataUnit`, :ref:`Dataset`, and
:ref:`Quantum` metadata in any :ref:`Registry`.
Implementations may choose to add fields to any of the tables described below, but they must have at least
the fields shown here.
The SQL dialect used to construct queries against the Common Schema is TBD; because different implementations may use different database systems, we can in general only support a limited common dialect.

The common schema is only intended to be used for SELECT queries.
Operations that add or remove :ref:`DataUnits <DataUnit>` or :ref:`Datasets <Dataset>` (or types thereof) to/from a :ref:`Registry` will be supported through Python APIs, but the SQL behind these APIs may be specific to the actual (private) schema used to implement the data collection and possibly the database system and its associated SQL dialect.

.. _cs_camera_dataunits:

Camera DataUnits
================

.. _cs_table_Camera:

+------------+---------+-------------+
| *Camera*                           |
+============+=========+=============+
| camera_id  | int     | PRIMARY KEY |
+------------+---------+-------------+
| name       | varchar | UNIQUE      |
+------------+---------+-------------+

Entries in the :ref:`Camera <cs_table_Camera>` table are essentially just sources of raw data with a
constant layout of PhysicalSensors and a self-constent numbering system for
Visits.  Different versions of the same camera (due to e.g. changes in
hardware) should still correspond to a single row in this table.

.. _cs_table_AbstractFilter:

+--------------------+---------+------------------+
| *AbstractFilter*                                |
+====================+=========+==================+
| abstract_filter_id | int     | PRIMARY KEY      |
+--------------------+---------+------------------+
| name               | varchar | NOT NULL, UNIQUE |
+--------------------+---------+------------------+

.. _cs_table_PhysicalFilter:

+--------------------+---------+------------------------------------------------+
| *PhysicalFilter*                                                              |
+====================+=========+================================================+
| physical_filter_id | int     | PRIMARY KEY                                    |
+--------------------+---------+------------------------------------------------+
| name               | varchar | NOT NULL                                       |
+--------------------+---------+------------------------------------------------+
| camera_id          | int     | NOT NULL, REFERENCES Camera (camera_id)        |
+--------------------+---------+------------------------------------------------+
| abstract_filter_id | int     | REFERENCES AbstractFilter (abstract_filter_id) |
+--------------------+---------+------------------------------------------------+
| CONSTRAINT UNIQUE (name, camera_id)                                           |
+--------------------+---------+------------------------------------------------+

Entries in the :ref:`PhysicalFilter <cs_table_PhysicalFilter>` table represent
the bandpass filters that can be associated with a particular visit.
These are different from :ref:`AbstractFilters <cs_table_AbstractFilters>`,
which are used to label Datasets that aggregate data from multiple Visits.
Having these two different :ref:`DataUnits <DataUnit>` for filters is necessary to make it
possible to combine data from Visits taken with different filters.  A
PhysicalFilter may or may not be associated with a particular AbstractFilter.
AbstractFilter is the only :ref:`DataUnit` not associated with either a Camera or a
SkyMap.

.. _cs_table_PhysicalSensor:

+--------------------+---------+-----------------------------------------+
| *PhysicalSensor*   |                                                   |
+====================+=========+=========================================+
| physical_sensor_id | int     | PRIMARY KEY                             |
+--------------------+---------+-----------------------------------------+
| name               | varchar | NOT NULL                                |
+--------------------+---------+-----------------------------------------+
| number             | varchar | NOT NULL                                |
+--------------------+---------+-----------------------------------------+
| camera_id          | int     | NOT NULL, REFERENCES Camera (camera_id) |
+--------------------+---------+-----------------------------------------+
| group              | varchar |                                         |
+--------------------+---------+-----------------------------------------+
| purpose            | varchar |                                         |
+--------------------+---------+-----------------------------------------+
| CONSTRAINT UNIQUE (name, camera_id)                                    |
+--------------------+---------+-----------------------------------------+

:ref:`PhysicalSensors <cs_table_PhysicalSensor>` actually represent the "slot" for a sensor in a camera,
independent of both any observations and the actual detector (which may change
over the life of the camera).  The ``group`` field may mean different things
for different cameras (such as rafts for LSST, or groups of sensors oriented
the same way relative to the focal plane for HSC).  The ``purpose`` field
indicates the role of the sensor (such as science, wavefront, or guiding).
Because some cameras identify sensors with string names and other use numbers,
we provide fields for both; the name may be a stringified integer, and the
number may be autoincrement.

.. _cs_table_Visit:

+--------------------+----------+----------------------------------------------------------+
| *Visit*                                                                                  |
+====================+==========+==========================================================+
| visit_id           | int      | PRIMARY KEY                                              |
+--------------------+----------+----------------------------------------------------------+
| number             | int      | NOT NULL                                                 |
+--------------------+----------+----------------------------------------------------------+
| camera_id          | int      | NOT NULL, REFERENCES Camera (camera_id)                  |
+--------------------+----------+----------------------------------------------------------+
| physical_filter_id | int      | NOT NULL, REFERENCES PhysicalFilter (physical_filter_id) |
+--------------------+----------+----------------------------------------------------------+
| obs_begin          | datetime | NOT NULL                                                 |
+--------------------+----------+----------------------------------------------------------+
| obs_end            | datetime | NOT NULL                                                 |
+--------------------+----------+----------------------------------------------------------+
| region             | blob     |                                                          |
+--------------------+----------+----------------------------------------------------------+
| CONSTRAINT UNIQUE (num, camera_id)                                                       |
+--------------------+----------+----------------------------------------------------------+

Entries in the :ref:`Visit <cs_table_Visit>` table correspond to observations with the full camera at
a particular pointing, possibly comprised of multiple exposures (Snaps).  A
Visit's ``region`` field holds an approximate but inclusive representation of
its position on the sky that can be compared to the ``regions`` of other
DataUnits.

.. _cs_table_ObservedSensor:

+--------------------+------+----------------------------------------------------------+
| *ObservedSensor*                                                                     |
+====================+======+==========================================================+
| observed_sensor_id | int  | PRIMARY KEY                                              |
+--------------------+------+----------------------------------------------------------+
| visit_id           | int  | NOT NULL, REFERENCES Visit (visit_id)                    |
+--------------------+------+----------------------------------------------------------+
| physical_sensor_id | int  | NOT NULL, REFERENCES PhysicalSensor (physical_sensor_id) |
+--------------------+------+----------------------------------------------------------+
| region             | blob |                                                          |
+--------------------+------+----------------------------------------------------------+
| CONSTRAINT UNIQUE (visit_id, physical_sensor_id)                                     |
+--------------------+------+----------------------------------------------------------+

An :ref:`ObservedSensor <cs_table_ObservedSensor>` is simply a combination of
a Visit and a PhysicalSensor, but unlike most other :ref:`DataUnit` combinations (which
are not typically :ref:`DataUnits <DataUnit>` themselves), this one is both ubuiquitous
and contains additional information: a ``region`` that represents the position of the
observed sensor image on the sky.

.. _cs_table_Snap:

+-----------+----------+------------------------------------------+
| *Snap*                                                          |
+===========+==========+==========================================+
| snap_id   | int      | PRIMARY KEY                              |
+-----------+----------+------------------------------------------+
| visit_id  | int      | PRIMARY KEY, REFERENCES Visit (visit_id) |
+-----------+----------+------------------------------------------+
| index     | int      | NOT NULL                                 |
+-----------+----------+------------------------------------------+
| obs_begin | datetime | NOT NULL                                 |
+-----------+----------+------------------------------------------+
| obs_end   | datetime | NOT NULL                                 |
+-----------+----------+------------------------------------------+
| CONSTRAINT UNIQUE (visit_id, index)                             |
+-----------+----------+------------------------------------------+

A :ref:`Snap <cs_table_Snap>` is a single-exposure subset of a Visit.

.. note::

    Most non-LSST Visits will have only a single Snap.

.. _cs_skymap_dataunits:

SkyMap DataUnits
================

.. _cs_table_SkyMap:

+-----------+---------+------------------+
| *SkyMap*                               |
+===========+=========+==================+
| skymap_id | int     | PRIMARY KEY      |
+-----------+---------+------------------+
| name      | varchar | NOT NULL, UNIQUE |
+-----------+---------+------------------+

Each :ref:`SkyMap <cs_table_Skymap>` entry represents a different way to subdivide the sky into tracts
and patches, including any parameters involved in those defitions (i.e.
different configurations of the same ``lsst.skymap.BaseSkyMap`` subclass yield
different rows).

.. todo::

    While SkyMaps need unique, human-readable names, it may also
    be wise to add a hash or pickle of the SkyMap instance that defines the
    mapping to avoid duplicate entries (not yet included).

.. _cs_table_Tract:

+-----------+------+-----------------------------------------+
| *Tract*                                                    |
+===========+======+=========================================+
| tract_id  | int  | PRIMARY KEY                             |
+-----------+------+-----------------------------------------+
| number    | int  | NOT NULL                                |
+-----------+------+-----------------------------------------+
| skymap_id | int  | NOT NULL, REFERENCES SkyMap (skymap_id) |
+-----------+------+-----------------------------------------+
| region    | blob |                                         |
+-----------+------+-----------------------------------------+
| CONSTRAINT UNIQUE (skymap_id, num)                         |
+-----------+------+-----------------------------------------+

A :ref:`Tract <cs_table_Tract>` is a contiguous, simple area on the sky with a 2-d Euclidian
coordinate system defined by a single map projection.

.. todo::

    If the parameters of the sky projection and the Tract's various bounding boxes
    can be standardized across all SkyMap implementations, it may be useful to
    include them in the table as well.

.. _cs_table_Patch:

+----------+------+--------+------------------------------+
| *Patch*                                                 |
+==========+======+========+==============================+
| patch_id | int  | PRIMARY KEY                           |
+----------+------+--------+------------------------------+
| tract_id | int  | NOT NULL, REFERENCES Tract (tract_id) |
+----------+------+--------+------------------------------+
| index    | int  | NOT NULL                              |
+----------+------+--------+------------------------------+
| region   | blob |                                       |
+----------+------+--------+------------------------------+
| CONSTRAINT UNIQUE (tract_id, index)                     |
+----------+------+--------+------------------------------+

:ref:`Tracts <cs_table_Tract>` are subdivided into :ref:`Patches <cs_table_Patch>`,
which share the Tract coordinate system and define similarly-sized regions that
overlap by a configurable amount.  As with Tracts, we may want to include fields
to describe Patch boundaries in this table in the future.

.. _cs_calibration_dataunits:

Calibration DataUnits
=====================

.. _cs_table_MasterCalib:

+--------------------+-----+----------------------------------------------------------+
| *MasterCalib*                                                                       |
+====================+=====+==========================================================+
| master_calib_id    | int | PRIMARY KEY                                              |
+--------------------+-----+----------------------------------------------------------+
| camera_id          | int | NOT NULL, REFERENCES Camera (camera_id)                  |
+--------------------+-----+----------------------------------------------------------+
| physical_filter_id | int | NOT NULL, REFERENCES PhysicalFilter (physical_filter_id) |
+--------------------+-----+----------------------------------------------------------+
| UNIQUE (camera_id, physical_filter_id)                                              |
+--------------------+-----+----------------------------------------------------------+

:ref:`Master calibration products <cs_table_MasterCalib>` are defined over a range
of Visits from a given Camera (see :ref:`MasterCalibVisitJoin <cs_table_MasterCalibVisitJoin>`).
Calibration products may additionally be specialized for a particular
PhysicalFilter, or may be appropriate for all PhysicalFilters by setting the
``physical_filter_id`` field to ``NULL``.

.. _cs_dataunit_joins:

DataUnit Joins
==============

The spatial join tables are calculated, and may be implemented as views
if those calculations can be done within the database efficiently.
The :ref:`MasterCalibVisitJoin <cs_table_MasterCalibVisitJoin>` table is
not calculated; its entries should be added whenever new
:ref:`MasterCalib <cs_table_MasterCalib>` entries are added.

.. _cs_table_MasterCalibVisitJoin:

+-----------------+-----+----------------------------------------------------+
| *MasterCalibVisitJoin*                                                     |
+=================+=====+====================================================+
| master_calib_id | int | NOT NULL, REFERENCES MasterCalib (master_calib_id) |
+-----------------+-----+----------------------------------------------------+
| visit_id        | int | REFERENCES Visit (visit_id)                        |
+-----------------+-----+----------------------------------------------------+

.. _cs_table_SensorTractJoin:

+--------------------+-----+----------------------------------------------------------+
| *SensorTractJoin*                                                                   |
+====================+=====+==========================================================+
| observed_sensor_id | int | NOT NULL, REFERENCES ObservedSensor (observed_sensor_id) |
+--------------------+-----+----------------------------------------------------------+
| tract_id           | int | NOT NULL, REFERENCES Tract (tract_id)                    |
+--------------------+-----+----------------------------------------------------------+
| CONSTRAINT UNIQUE (observed_sensor_id, tract_id)                                    |
+--------------------+-----+----------------------------------------------------------+

.. _cs_table_SensorPatchJoin:

+--------------------+-----+-----------------------------------------------+
| *SensorPatchJoin*                                                        |
+====================+=====+===============================================+
| observed_sensor_id | int | NOT NULL, REFERENCES ObservedSensor (unit_id) |
+--------------------+-----+-----------------------------------------------+
| patch_id           | int | NOT NULL, REFERENCES Patch (unit_id)          |
+--------------------+-----+-----------------------------------------------+
| CONSTRAINT UNIQUE (observed_sensor_id, patch_id)                         |
+--------------------+-----+-----------------------------------------------+

.. _cs_table_VisitTractJoin:

+----------+-----+---------------------------------------+
| *VisitTractJoin*                                       |
+==========+=====+=======================================+
| visit_id | int | NOT NULL, REFERENCES Visit (visit_id) |
+----------+-----+---------------------------------------+
| tract_id | int | NOT NULL, REFERENCES Tract (tract_id) |
+----------+-----+---------------------------------------+
| CONSTRAINT UNIQUE (visit_id, tract_id)                 |
+----------+-----+---------------------------------------+

.. _cs_table_VisitPatchJoin:

+----------+-----+---------------------------------------+
| *VisitPatchJoin*                                       |
+==========+=====+=======================================+
| visit_id | int | NOT NULL, REFERENCES Visit (visit_id) |
+----------+-----+---------------------------------------+
| patch_id | int | NOT NULL, REFERENCES Patch (patch_id) |
+----------+-----+---------------------------------------+
| CONSTRAINT UNIQUE (visit_id, patch_id)                 |
+----------+-----+---------------------------------------+

.. _cs_datasettypes_and_metatype:

DatasetTypes and MetaType
=========================

.. _cs_table_DatasetMetatype:

+-------------+---------+-------------+
| *DatasetMetatype*                   |
+=============+=========+=============+
| metatype_id | int     | PRIMARY KEY |
+-------------+---------+-------------+
| name        | varchar | NOT NULL    |
+-------------+---------+-------------+

.. _cs_table_DatasetMetatypeComposition:

+----------------+---------+------------------------------------------------------------+
| *DatasetMetatypeComposition*                                                          |
+================+=========+============================================================+
| parent_id      | int     | NOT NULL, REFERENCES DatasetMetatype (dataset_metatype_id) |
+----------------+---------+------------------------------------------------------------+
| component_id   | int     | NOT NULL, REFERENCES DatasetMetatype (dataset_metatype_id) |
+----------------+---------+------------------------------------------------------------+
| component_name | varchar | NOT NULL                                                   |
+----------------+---------+------------------------------------------------------------+

.. _cs_table_DatasetType:

+---------------------+---------+------------------------------------------------------------+
| *DatasetType*                                                                              |
+=====================+=========+============================================================+
| dataset_type_id     | int     | PRIMARY KEY                                                |
+---------------------+---------+------------------------------------------------------------+
| name                | varchar | NOT NULL                                                   |
+---------------------+---------+------------------------------------------------------------+
| template            | varchar |                                                            |
+---------------------+---------+------------------------------------------------------------+
| dataset_metatype_id | int     | NOT NULL, REFERENCES DatasetMetatype (dataset_metatype_id) |
+---------------------+---------+------------------------------------------------------------+

.. _cs_table_DatasetTypeUnits:

+-----------------+---------+-------------+
| *DatasetTypeUnits*                      |
+=================+=========+=============+
| dataset_type_id | int     | PRIMARY KEY |
+-----------------+---------+-------------+
| unit_name       | varchar | NOT NULL    |
+-----------------+---------+-------------+


.. _cs_datasets:

Datasets
========

There's table for the entire database, so IDs are unique even across
:ref:`Collections <Collection>`.  The ``dataref_pack`` field contains
an ID that is unique only with a collection, constructed by packing
together the associated units (the *path* string passed to ``DataStore.put``
would be a viable but probably inefficient choice).

.. _cs_table_Dataset:

+-------------------+---------+---------------------------------+
| *Dataset*                                                     |
+-------------------+---------+---------------------------------+
| dataset_id        | int     | PRIMARY KEY                     |
+-------------------+---------+---------------------------------+
| dataset_type_id   |         | NOT NULL                        |
+-------------------+---------+---------------------------------+
| dataref_pack      | binary  | NOT NULL                        |
+-------------------+---------+---------------------------------+
| uri               | varchar |                                 |
+-------------------+---------+---------------------------------+
| producer_id       | int     | REFERENCES Quantum (quantum_id) |
+-------------------+---------+---------------------------------+
| parent_dataset_id | int     | REFERENCES Dataset (dataset_id) |
+-------------------+---------+---------------------------------+


.. _cs_composite_datasets:

Composite Datasets
==================

* If a virtual :ref:`Dataset` was created by writing multiple component Datasets,
  the parent :ref:`DatasetType's <cs_table_DatasetType>` ``template`` field and the parent
  Dataset's ``uri`` field may be null (depending on whether there was a also parent
  Dataset stored whose components should be overridden).
  
* If a single :ref:`Dataset` was written and we're defining virtual components,
  the component :ref:`DatasetTypes <cs_table_DatasetType>` should have null ``template``
  fields, but the component Datasets will have non-null ``uri`` fields with values created
  by the :ref:`Datastore`.

.. _cs_table_DatasetComposition:

+----------------+-----+-------------------------------------------+
| *DatasetComposition*                                             |
+================+=====+===========================================+
| parent_id      | int | NOT NULL, REFERENCES Dataset (dataset_id) |
+----------------+-----+-------------------------------------------+
| component_id   | int | NOT NULL, REFERENCES Dataset (dataset_id) |
+----------------+-----+-------------------------------------------+
| component_name | int | NOT NULL                                  |
+----------------+-----+-------------------------------------------+

.. _cs_tags:

Tags
====

Tags to define multiple :ref:`Collections <Collection>` in a single database

.. _cs_table_CollectionTag:

+-------------------+---------+-------------+
| *CollectionTag*                           |
+-------------------+---------+-------------+
| collection_tag_id | int     | PRIMARY KEY |
+-------------------+---------+-------------+
| name              | varchar | NOT NULL    |
+-------------------+---------+-------------+
| CONSTRAINT UNIQUE (name)                  |
+-------------------+---------+-------------+

.. _cs_table_DatasetCollectionTagJoin:

+-------------------+-----+-----------------------------------------------------------+
| *DatasetCollectionTagJoin*                                                          |
+===================+=====+===========================================================+
| collection_tag_id | int | PRIMARY KEY, REFERENCES CollectionTag (collection_tag_id) |
+-------------------+-----+-----------------------------------------------------------+
| dataset_id        | int | NOT NULL, REFERENCES Dataset (dataset_id)                 |
+-------------------+-----+-----------------------------------------------------------+

.. _cs_table_DatasetTypeCollectionTagJoin:

+-------------------+-----+-----------------------------------------------------------+
| *DatasetTypeCollectionTagJoin*                                                      |
+===================+=====+===========================================================+
| collection_tag_id | int | PRIMARY KEY, REFERENCES CollectionTag (collection_tag_id) |
+-------------------+-----+-----------------------------------------------------------+
| dataset_type_id   | int | NOT NULL, REFERENCES DatasetType (dataset_type_id)        |
+-------------------+-----+-----------------------------------------------------------+
    
.. note::

    In a single-collection database, these tables may possibly be absent for space efficiency.


.. _cs_dataset_dataunit_joins:

Dataset-DataUnit joins
======================

.. _cs_table_PhysicalFilterDatasetJoin:

+--------------------+-----+----------------------------------------------------------+
| *PhysicalFilterDatasetJoin*                                                         |
+====================+=====+==========================================================+
| physical_filter_id | int | NOT NULL, REFERENCES PhysicalFilter (physical_filter_id) |
+--------------------+-----+----------------------------------------------------------+
| dataset_id         | int | NOT NULL, REFERENCES Dataset (dataset_id)                |
+--------------------+-----+----------------------------------------------------------+
    
.. _cs_table_PhysicalSensorDatasetJoin:

+--------------------+-----+----------------------------------------------------------+
| *PhysicalSensorDatasetJoin*                                                         |
+====================+=====+==========================================================+
| physical_sensor_id | int | NOT NULL, REFERENCES PhysicalSensor (physical_sensor_id) |
+--------------------+-----+----------------------------------------------------------+
| dataset_id         | int | NOT NULL, REFERENCES Dataset (dataset_id)                |
+--------------------+-----+----------------------------------------------------------+

.. _cs_table_VisitDatasetJoin:

+------------+-----+------------------------------------------------------------------+
| *VisitDatasetJoin*                                                                  |
+============+=====+==================================================================+
| visit_id   | int | NOT NULL, REFERENCES Visit (visit_id)                            |
+------------+-----+------------------------------------------------------------------+
| dataset_id | int | NOT NULL, REFERENCES Dataset (dataset_id)                        |
+------------+-----+------------------------------------------------------------------+

.. _cs_table_ObservedSensorDatasetJoin:

+--------------------+-----+----------------------------------------------------------+
| *ObservedSensorDatasetJoin*                                                         |
+====================+=====+==========================================================+
| observed_sensor_id | int | NOT NULL, REFERENCES ObservedSensor (observed_sensor_id) |
+--------------------+-----+----------------------------------------------------------+
| dataset_id         | int | NOT NULL, REFERENCES Dataset (dataset_id)                |
+--------------------+-----+----------------------------------------------------------+

.. _cs_table_SnapDatasetJoin:

+------------+-----+------------------------------------------------------------------+
| *SnapDatasetJoin*                                                                   |
+============+=====+==================================================================+
| snap_id    | int | NOT NULL, REFERENCES Snap (snap_id)                              |
+------------+-----+------------------------------------------------------------------+
| dataset_id | int | NOT NULL, REFERENCES Dataset (dataset_id)                        |
+------------+-----+------------------------------------------------------------------+

.. _cs_table_AbstractFilterDatasetJoin:

+--------------------+-----+----------------------------------------------------------+
| *AbstractFilterDatasetJoin*                                                         |
+====================+=====+==========================================================+
| abstract_filter_id | int | NOT NULL, REFERENCES AbstractFilter (abstract_filter_id) |
+--------------------+-----+----------------------------------------------------------+
| dataset_id         | int | NOT NULL, REFERENCES Dataset (dataset_id)                |
+--------------------+-----+----------------------------------------------------------+

.. _cs_table_TractDatasetJoin:

+--------------------+-----+----------------------------------------------------------+
| *TractDatasetJoin*                                                                  |
+====================+=====+==========================================================+
| tract_id           | int | NOT NULL, REFERENCES Tract (tract_id)                    |
+--------------------+-----+----------------------------------------------------------+
| dataset_id         | int | NOT NULL, REFERENCES Dataset (dataset_id)                |
+--------------------+-----+----------------------------------------------------------+

.. _cs_table_PatchDatasetJoin:

+------------+-----+------------------------------------------------------------------+
| *PatchDatasetJoin*                                                                  |
+============+=====+==================================================================+
| patch_id   | int | NOT NULL, REFERENCES Patch (patch_id)                            |
+------------+-----+------------------------------------------------------------------+
| dataset_id | int | NOT NULL, REFERENCES Dataset (dataset_id)                        |
+------------+-----+------------------------------------------------------------------+

Views for DatasetExpressions
============================

:: todo:

    Rewrite this section to describe views created on-the-fly by Registry.makeDataGraph, rather than something intrinsic to the Common Schema.

 - There is a table for each :ref:`DatasetType`, with entries corresponding to
   :ref:`Datasets <Dataset>` that are present in the :ref:`Collection` (and
   only these).

 - The name of the table should be the name of the :ref:`DatasetType`.

 - The table has a foreign key field relating to each :ref:`DataUnit` table that
   is used to label the :ref:`DatasetType`.

 - The table has at least the following additional fields:

+------------+--------+---------------------------------------------+
| dataset_id | uint64 | PRIMARY KEY REFERENCES Dataset (dataset_id) |
+------------+--------+---------------------------------------------+
| uri        | str    |                                             |
+------------+--------+---------------------------------------------+

The ``dataset_id`` field is both a primary key that must be unique across
elements in this table and a link to the more general Dataset table described in
the :ref:`Provenance <cs_Provenance>` section; this means that it must be
globally unique across *all* dataset tables, virtually guaranteeing that these
per-:ref:`DatasetType` tables will be implemented as views into a larger table.

The ``uri`` field contains a string that can be used to local the file or other
entity that contains the stored :ref:`Dataset`.  While this may be generated
differently according to different configurations when the file is first
written, after it is written we do not expect the name to change and hence
record it in the database; this reduces the need for implementations to
be aware of past configurations in addition to their current confirguration. For
multi-file composite datasets, this field should be ``NULL``, and another table
(TBD) can be used to associate the composite with its leaf-node :ref:`Datasets
<Dataset>`.


.. _cs_provenance:

Provenance
==========

.. todo::

    Figure out if this section is still current.

.. todo::

    Should DatasetTypes be associated with Collections?

.. _cs_table_DatasetType:

+-----------------+--------+----------------------------------------+
| *DatasetType*                                                     |
+=================+========+========================================+
| dataset_type_id | uint64 | PRIMARY KEY                            |
+-----------------+--------+----------------------------------------+
| name            | str    | NOT NULL UNIQUE                        |
+-----------------+--------+----------------------------------------+

.. _cs_table_Dataset:

+-------------+--------+---------------------------------+
| *Dataset*                                              |
+=============+========+=================================+
| dataset_id  | uint64 | PRIMARY KEY                     |
+-------------+--------+---------------------------------+
| uri         | str    |                                 |
+-------------+--------+---------------------------------+
| producer_id | uint64 | REFERENCES Quantum (quantum_id) |
+-------------+--------+---------------------------------+

These tables provide another view of the information in the
per-:ref:`DatasetType` tables described in the :ref:`Datasets <cs_datasets>`
section, with the following differences:

 - They provide no way to join with :ref:`DataUnit` tables (aside from joining
   with the per-:ref:`DatasetType` tables themselves on the ``dataset_id``
   field).

 - The Dataset table must contain entries for at least all :ref:`Datasets
   <Dataset>` in the :ref:`Collection`, but it may contain entries for
   additional :ref:`Datasets <Dataset>` as well.

 - These add the ``producer_id`` field, which records the Quantum that produced
   the dataset (if applicable).

 .. _cs_table_Quantum:

+----------------------+-------------------------------------------+
| *Quantum*                                                        |
+======================+===========================================+
| quantum_id | int     | PRIMARY KEY                               |
+----------------------+-------------------------------------------+
| task       | varchar |                                           |
+----------------------+-------------------------------------------+
| config_id  | int     | NOT NULL, REFERENCES Dataset (dataset_id) |
+----------------------+-------------------------------------------+

.. _cs_table_DatasetConsumer:

+-------------+--------+---------------------------------------------+
| *DatasetConsumer*                                                  |
+=============+========+=============================================+
| quantum_id  | uint64 | NOT NULL REFERENCES Quantum (quantum_id)    |
+-------------+--------+---------------------------------------------+
| dataset_id  | uint64 | NOT NULL REFERENCES Dataset (dataset_id)    |
+-------------+--------+---------------------------------------------+

A Quantum (a term borrowed from the SuperTask design) is a discrete unit of
work, such as a single invocation of ``SuperTask.runQuantum``.  It may also be
used here to describe other actions that produce and/or consume :ref:`Datasets
<Dataset>`.  The ``config_id`` and ``env_id`` provide links to :ref:`Datasets
<Dataset>` that hold the configuration and a description of the software and
compute environments.

Because each :ref:`Dataset` can have multiple consumers but at most one
producer, the Quantum that produces a Dataset is recorded in the
Dataset table itself, while the separate join table DatasetConsumers is
used to record the Quantum entries that utilized a Dataset entry.

There is no guarantee that the full provenance of a :ref:`Dataset` is captured
by these tables in a particular :ref:`Collection`, unless the :ref:`Dataset`
and all of its dependencies (any datasets consumed by its producer Quantum,
recursively) are also in the :ref:`Collection`.  When this is not the case,
the provenance information *may* be present (with dependencies included in the
Dataset table), or the ``Dataset.producer_id`` field may be null.  The Dataset
table may also contain entries that are not related at all to those in the
:ref:`Collection`; we have no obvious use for such a restriction, and it is
potentially burdensome on implementations.

.. note::

   As with everything else in the Common Schema, the provenance system used in
   the operations data backbone will almost certainly involve additional fields
   and tables, and what's in the Common Schema will just be a view.  But
   provenance tables here are even more of a blind straw-man than the rest of
   the Common Schema (which is derived more directly from SuperTask
   requirements), and I certainly expect it to change based on feedback; I
   think this reflects all that we need outside the operations system, but how
   operations implements their system should probably influence the details
   (such as how we represent configuration and software environment information).
