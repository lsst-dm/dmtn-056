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
:ref:`InMemoryDataset`.  The :ref:`Butler` is the user-facing interface employed to
load and store :ref:`InMemoryDatasets <InMemoryDataset>`, and query the metadata of
and relationships between :ref:`Datasets <Dataset>`.

Relations between :ref:`Datasets <Dataset>`, :ref:`Quanta <Quantum>`, and locations
for stored objects are kept in a SQL database which implements the :ref:`Common Schema <CommonSchema>`.
The :ref:`Registry` class provides an interface to such a database.

In the database, the :ref:`Datasets <Dataset>` are grouped into :ref:`Collections <Collection>`,
which are identified by a *CollectionTag*.
Within a given :ref:`Collection` a :ref:`Dataset` is uniquely identified by a :ref:`DatasetRef`.

Conceptually a :ref:`DatasetRef` is a combination of a :ref:`DatasetType` (e.g. ``calexp``)
and a set of :ref:`DataUnits <DataUnit>`.  A :ref:`DataUnit` is a discrete unit of
data (e.g. a particular visit, tract, or filter).

A :ref:`DatasetRef` is thus a label that refers to different-but-related :ref:`Datasets <Dataset>`
in different :ref:`Collections <Collection>`. An example is a ``calexp`` for a particular visit
and CCD produced in different processing runs (with each processing run thus being a :ref:`Collection`).

A :py:class:`DatasetLabel` is a opaque, lightweight :ref:`DatasetRef` that is easier to
construct; it just holds POD values that identify :ref:`DataUnits <DataUnit>` and a :ref:`DatasetType`.

Storing the :ref:`Datasets <Dataset>` themselves, as opposed to information about them, is the
responsibility of the :ref:`Datastore`.

An overview of the framework structure can be seen in the following figure:

.. _framework_structure:

.. image:: images/concepts.png
    :scale: 75%

Users primarily interact with a particular :ref:`Butler` instance that
**provides access to a single** :ref:`Collection`.

They can use this instance to:

* Load a :ref:`Dataset` associated with a particular :py:class:`DatasetLabel`,
* Store a :ref:`Dataset` associated with a particular :py:class:`DatasetLabel`, and
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
    In some cases, such as when server-side slicing of a :ref:`Dataset` is needed, a daemon for at least the :ref:`Datastore` will be required.

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

The user has a :py:class:`DatasetLabel`, constructed or obtained by a query and wishes to retrieve the associated :ref:`InMemoryDataset`.

This proceeds allong the following steps:

1. User calls: ``butler.get(label)``.
2. :ref:`Butler` forwards this call to its :ref:`Registry`, adding the :ref:`CollectionTag <Collection>` it was configured with (i.e. ``butler.registry.find(butler.config.inputCollection, label)``).
3. :ref:`Registry` performs the lookup on the server using SQL and returns the :ref:`URI` for the stored :ref:`Dataset` (via a :py:class:`DatasetHandle`)
4. :ref:`Butler` forwards the request, with both the :ref:`URI` and the :ref:`DatasetMetatype`, to the :ref:`Datastore` client (i.e. ``butler.datastore.get(handle.uri, handle.type.meta)``).
5. :ref:`Datastore` client requests a serialized version of the :ref:`Dataset` from the server using the :ref:`URI`.
6. Using the :ref:`DatasetMetatype` to determine the appropriate deserialization function, the :ref:`Datastore` client then materializes the :ref:`InMemoryDataset` and returns it to the :ref:`Butler`.
7. :ref:`Butler` then returns the :ref:`InMemoryDataset` to the user.

See :py:meth:`the API documentation <Butler.get>` for more information.

.. note::

    The :ref:`Datastore` request can be a simple ``HTTP GET`` request for a stored FITS file, or something more complicated.
    In the former case the materialization would be a simple FITS read (e.g. of a ``calexp``), with the reader determined by the :ref:`DatasetMetatype` retrieved from the :ref:`Registry`.

.. note::

    The serialized version sent over the wire doesn't have to correspond to the format stored on disk in the :ref:`Datastore` server.  It just needs to be serialized in the form expected by the client.

Basic ``put``
-------------

The user has a :ref:`InMemoryDataset` and wishes to store this at a particular :py:class:`DatasetLabel`.

This proceeds allong the following steps:

1. User calls: ``butler.put(label, inMemoryDataset)``.
2. :ref:`Butler` expands the :py:class:`DatasetLabel` into a full :py:class:`DatasetRef` using the :ref:`Registry`, by calling ``datasetRef = butler.registry.getDatasetMetatype(butler.config.outputCollection, datasetRef)``.
3. :ref:`Butler` obtains a :ref:`Path` by calling ``path = datasetRef.makePath(butler.config.outputCollection, template)``. This path is a hint to be used by the :ref:`Datastore` to decide where to store it.  The template is provided by the :ref:`Registry` but may be overridden by the :ref:`Butler`.
4. :ref:`Butler` then asks the :ref:`Datastore` client to store the file by calling: ``butler.datastore.put(inMemoryDataset, datasetRef.type.meta, path)``.
5. The :ref:`Datastore` client then uses the serialization function associated with the :ref:`DatasetMetatype` to serialize the :ref:`InMemoryDataset` and sends it to the :ref:`Datastore` server.
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

The :py:class:`DatasetHandle` returned by :py:meth:`Registry.find` therefore not only includes the :ref:`URI` and :ref:`DatasetMetatype` of the **parent** (associated with the :ref:`DatasetRef`), but also a ``components`` dictionary of ``name : DatasetHandle`` specifying its **children**.

The :ref:`Butler` retrieves **all** :ref:`Datasets <Dataset>` from the :ref:`Datastore` as :ref:`InMemoryDatasets <InMemoryDataset>` and then calls the ``assemble`` function associated with the :ref:`DatasetMetatype` of the primary to create the final composed :ref:`InMemoryDataset`.

This process is most easily understood by reading the API documentation for :py:meth:`butler.get <Butler.get>` and :py:meth:`butler.put <Butler.put>`.

#########
Reference
#########

.. _Dataset:

Dataset
=======

A Dataset is a discrete entity of stored data, possibly with associated metadata.

Datasets are uniquely identified by either a :ref:`URI` or the combination of a :ref:`CollectionTag <Collection>` and a :ref:`DatasetRef`.

Example: a "calexp" for a single visit and sensor produced by a processing run.

A Dataset may be *composite*, which means it contains one or more named *component* Datasets.
Composites may be stored either by storing the parent in a single file or by storing the components separately.
Some composites simply aggregate that are always written as part of other :ref:`Datasets <Dataset>`, and are themselves read-only.

Datasets may also be *sliced*, which yields an :ref:`InMemoryDataset` of the same type containing a smaller amount of data, defined by some parameters.
Subimages and filters on catalogs are both considered slices.

Transition
----------

The Dataset concept has essentially the same meaning that it did in the v14 Butler.

A Dataset is analogous to an Open Provenance Model "artifact".

Python API
----------

The Python representation of a :ref:`Dataset` is in some sense a :ref:`InMemoryDataset`, and hence we have no Python "Dataset" class.
However, we have several Python objects that act like pointers to :ref:`Datasets <Dataset>`.
These are described in the Python API section for :ref:`DatasetRef`.

SQL Representation
------------------

Datasets are represented by records in a single table that includes everything in a :ref:`Registry`, regardless of :ref:`Collection` or :ref:`DatasetType`:

.. _sql_Dataset:

+-------------------+---------+---------------------------------+
| *Dataset*                                                     |
+-------------------+---------+---------------------------------+
| dataset_id        | int     | PRIMARY KEY                     |
+-------------------+---------+---------------------------------+
| dataset_type_id   | int     | NOT NULL                        |
+-------------------+---------+---------------------------------+
| unit_pack         | binary  | NOT NULL                        |
+-------------------+---------+---------------------------------+
| uri               | varchar |                                 |
+-------------------+---------+---------------------------------+
| producer_id       | int     | REFERENCES Quantum (quantum_id) |
+-------------------+---------+---------------------------------+
| parent_dataset_id | int     | REFERENCES Dataset (dataset_id) |
+-------------------+---------+---------------------------------+

Using a single table (instead of per-:ref:`DatasetType` and/or per-:ref:`Collection` tables) ensures that table-creation permissions are not required when adding new :ref:`DatasetTypes <DatasetType>` or :ref:`Collections <Collection>`.  It also makes it easier to store provenance by associating :ref:`Datasets <Dataset>` with :ref:`Quanta <Quantum>`.

The disadvantage of this approach is that the connections between :ref:`Datasets <Dataset>` and :ref:`DataUnits <DataUnit>` must be stored in a set of :ref:`additional join tables <sql_dataset_dataunit_joins>` (one for each :ref:`DataUnit` table).
The connections are summarized by the ``unit_pack`` field, which contains an ID that is unique only within a :ref:`Collection` for a given :ref:`DatasetType`, constructed by bit-packing the values of the associated units (a :ref:`Path` would be a viable but probably inefficient choice).
While a ``unit_pack`` value cannot be used to reconstruct a full :ref:`DatasetRef`, a ``unit_pack`` value can be used to quickly search for the :ref:`Dataset` matching a given :ref:`DatasetRef`.
It also allows :py:meth:`Registry.merge` to be implemented purely as a database operation by using it as a GROUP BY column in a query over multiple :ref:`Collections <Collection>`.

Composite datasets are represented in SQL as a one-to-many self-join table on :ref:`Dataset <sql_Dataset>`:

.. _sql_DatasetComposition:

+----------------+-----+-------------------------------------------+
| *DatasetComposition*                                             |
+================+=====+===========================================+
| parent_id      | int | NOT NULL, REFERENCES Dataset (dataset_id) |
+----------------+-----+-------------------------------------------+
| component_id   | int | NOT NULL, REFERENCES Dataset (dataset_id) |
+----------------+-----+-------------------------------------------+
| component_name | int | NOT NULL                                  |
+----------------+-----+-------------------------------------------+


* If a virtual :ref:`Dataset` was created by writing multiple component Datasets, the parent :ref:`DatasetType's <sql_DatasetType>` ``template`` field and the parent Dataset's ``uri`` field may be null (depending on whether there was also a parent Dataset stored whose components should be overridden).

* If a single :ref:`Dataset` was written and we're defining virtual components, the component :ref:`DatasetTypes <sql_DatasetType>` should have null ``template`` fields, but the component Datasets will have non-null ``uri`` fields with values returned by the :ref:`Datastore` when :py:meth:`Datastore.put` was called on the parent.


.. _DatasetRef:

DatasetRef
==========

An identifier for a :ref:`Dataset` that can be used across different :ref:`Collections <Collection>` and :ref:`Registries <Registry>`.
A :ref:`DatasetRef` is effectively the combination of a :ref:`DatasetType` and a tuple of :ref:`DataUnits <DataUnit>`.

Transition
----------

The v14 Butler's DataRef class played a similar role.

The :py:class:`DatasetLabel` class also described here is more similar to the v14 Butler Data ID concept, though (like DatasetRef and DataRef, and unlike Data ID) it also holds a :ref:`DatasetType` name).

Python API
----------

The :py:class:`DatasetRef` class itself is the middle layer in a three-class hierarchy of objects that behave like pointers to :ref:`Datasets <Dataset>`.

.. digraph:: Dataset
    :align: center

    node[shape=record]
    edge[dir=back, arrowtail=empty]

    DatasetHandle;
    DatasetRef;
    DatasetLabel;

    DatasetHandle -> DatasetRef;
    DatasetRef -> DatasetLabel;

The ultimate base class and simplest of these, :py:class:`DatasetLabel`, is entirely opaque to the user; its internal state is visible only to a :ref:`Registry` (with which it has some Python approximation to a C++ "friend" relationship).
Unlike the other classes in the hierarchy, instances can be constructed directly from Python PODs, without access to a :ref:`Registry` (or :ref:`Datastore`).
Like a :py:class:`DatasetRef`, a :py:class:`DatasetLabel` only fully identifies a :ref:`Dataset` when combined with a :ref:`Collection`, and can be used to represent :ref:`Datasets <Dataset>` before they have been written.
Most interactive analysis code will interact primarily with :py:class:`DatasetLabels <DatasetLabel>`, as these provide the simplest, least-structured way to use the :ref:`Butler` interface.

The next class, :py:class:`DatasetRef` itself, provides access to the associated :ref:`DataUnit` instances and the :py:class:`DatasetType`.
A :py:class:`DatasetRef` instance cannot be constructed without a :ref:`Registry`, making it somewhat more cumbersome to use in interactive contexts.
The SuperTask pattern hides those extra construction steps from both SuperTask authors and operators, however, and :py:class:`DatasetRef` is the class SuperTask authors will use most.

Instances of the final class in the hierarchy, :py:class:`DatasetHandle`, always correspond to a :ref:`Datasets <Dataset>` that has already been stored in a :ref:`Datastore`.
In addition to the :ref:`DataUnits <DataUnit>` and :ref:`DatasetType` exposed by :py:class:`DatasetRef`, a :py:class:`DatasetHandle` also provides access to its :ref:`URI` and component :ref:`Datasets <Dataset>`.
The additional functionality provided by :py:class:`DatasetHandle` is rarely needed unless one is interacting directly with a :py:class:`Registry` or :py:class:`Datastore` (instead of a :py:class:`Butler`), but the :py:class:`DatasetRef` instances that appear in SuperTask code may actually be :py:class:`DatasetHandle` instances (in a language other than Python, this would have been handled as a :py:class:`DatasetRef` pointer to a :py:class:`DatasetHandle`, ensuring that the user sees only the :py:class:`DatasetRef` interface, but Python has no such concept).

All three classes are immutable.

.. py:class:: DatasetLabel

    .. py:method:: __init__(self, name, **units)

        Construct a DatasetLabel from the name of a :ref:`DatasetType` and a keyword arguments providing :ref:`DataUnit` key-value pairs.

.. py:class:: DatasetRef(DatasetLabel)

    .. py:attribute:: type

        Read-only instance attribute.

        The :py:class:`DatasetType` associated with the :ref:`Dataset` the :ref:`DatasetRef` points to.

    .. py:attribute:: units

        Read-only instance attribute.

        A tuple (or ``frozenset``?) of :py:class:`DataUnit` instances that label the :ref:`DatasetRef` within a :ref:`Collection`.
        Because the :py:class:`DataUnit` instances may link to other :py:class:`DataUnit` instances, a collection of DatasetRefs naturally forms a graph structure.
        This is discussed more fully in the documentation for :ref:`DataGraph`.

    .. py:method:: makePath(tag, template=None) -> Path

        Construct the :ref:`Path` part of a :ref:`URI` by filling in ``template`` with the :ref:`CollectionTag <Collection>` and the values in the :py:attr:`units` tuple.

        This is often just a storage hint since the :ref:`Datastore` will likely have to deviate from the provided path (in the case of an object-store for instance).

        Although a :ref:`Dataset` may belong to multiple :ref:`Collections <Collection>`, only the first :ref:`Collection` it is added to is used in its :ref:`Path`.

        :param str tag: a :ref:`CollectionTag <Collection>` indicating the :ref:`Collection` to which the :ref:`Dataset` will be added.

        :param str template: a path template to fill in.  If None, the :py:attr:`template <DatasetType.template>` attribute of :py:attr:`type` will be used.

        :returns: a str :ref:`Path`

    .. todo::

        Add method for packing DataUnits and a Collection into unique integer IDs.
        Need to think about whether that combination is actually globally unique if the first Collection a Dataset is defined in changes.

.. py:class:: DatasetHandle(DatasetRef)

    .. py:attribute:: uri

        Read-only instance attribute.

        The :ref:`URI` that holds the location of the :ref:`Dataset` in a :ref:`Datastore`.

    .. py:attribute:: components

        Read-only instance attribute.

        A :py:class:`dict` holding :py:class:`DatasetHandle` instances that correspond to this :ref:`Dataset's <Dataset>` named components.

        Empty (or ``None``?) if the :ref:`Dataset` is not a composite.


SQL Representation
------------------

As discussed in the description of the :ref:`Dataset` SQL representation, the :ref:`DataUnits <DataUnit>` in a :ref:`DatasetRefs <DatasetRef>` are related to :ref:`Datasets <Dataset>` by a :ref:`set of join tables <sql_dataset_dataunit_joins>`.
Each of these connects the :ref:`Dataset table's <sql_Dataset>` ``dataset_id`` to the primary key of a concrete :ref:`DataUnit` table.


.. _DatasetType:

DatasetType
===========

A named category of :ref:`Datasets <Dataset>` that defines how they are organized, related, and stored.

In addition to a name, a DatasetType includes:

 - a template string that can be used to construct a :ref:`Path` (may be overridden);
 - a tuple of :ref:`DataUnit <DataUnit>` types that define the structure of :ref:`DatasetRefs <DatasetRef>`;
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

        A string with ``str.format``-style replacement patterns that can be used to create a :ref:`Path` from a :ref:`CollectionTag <Collection>` and a :ref:`DatasetRef`.

        May be None to indicate a read-only :ref:`Dataset` or one whose templates must be provided at a higher level.

    .. py:attribute:: units

        Read-only instance attribute.

        A :py:class:`DataUnitTypeSet` that defines the :ref:`DatasetRefs <DatasetRef>` corresponding to this :ref:`DatasetType`.

    .. py:attribute:: meta

        Read-only instance attribute.

        A :py:class:`DatasetMetatype` subclass (not instance) that defines how this :ref:`DatasetType` is persisted.

SQL Representation
------------------

DatasetTypes are stored in a :ref:`Registry` using two tables.
The first has a single record for each DatasetType and contains most of the information that defines it:

.. _sql_DatasetType:

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

The second table has a many-to-one relationship with the first and holds the names of the :ref:`DataUnit` types utilized by its :ref:`DatasetRefs <DatasetRef>`:

.. _cs_table_DatasetTypeUnits:

+-----------------+---------+-------------+
| *DatasetTypeUnits*                      |
+=================+=========+=============+
| dataset_type_id | int     | PRIMARY KEY |
+-----------------+---------+-------------+
| unit_name       | varchar | NOT NULL    |
+-----------------+---------+-------------+


.. _InMemoryDataset:

InMemoryDataset
===============

The in-memory manifestation of a :ref:`Dataset`

Example: an ``afw.image.Exposure`` instance with the contents of a particular ``calexp``.

Transition
----------

The "python" and "persistable" entries in v14 Butler dataset policy files refer to Python and C++ InMemoryDataset types, respectively.

Python API
----------

While all InMemoryDatasets are Python objects, they have no common class or interface.

SQL Representation
------------------

InMemoryDatasets exist only in Python and do not have any SQL representation.


.. _DataUnit:

DataUnit
========

A discrete abstract unit of data that can be associated with metadata or used to label a :ref:`Dataset`.

Examples: individual Visits, Tracts, or Filters.

A DataUnit type may *depend* on another.  In SQL, this is expressed as a foreign key field in the table for the dependent DataUnit that points to the primary key field of its table for the DataUnit it depends on.

Some DataUnits represent joins between other DataUnits.  A join DataUnit *depends* on the two DataUnits it connects, but is also included automatically in any sequence or container in which its dependencies are both present.

Every DataUnit type also has a "value".  This is a POD (usually a string or integer, but sometimes a tuple of these) that is both its default human-readable representation *and* a "semi-unique" identifier for the DataUnit: when combined with the "values" of any other :ref:`DataUnit`

The :py:class:`DataUnitTypeSet` class provides methods that enforce and utilize these rules, providing a centralized implementation to which all other objects that operate on groups of DataUnits can delegate.

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

.. py:class:: DataUnitTypeSet

    An ordered tuple of unique DataUnit subclasses.

    Unlike a regular Python tuple or set, a DataUnitTypeSet's elements are always sorted (by the DataUnit type name, though the actual sort order is irrelevant).
    In addition, the inclusion of certain DataUnit types can automatically lead to to the inclusion of others.  This can happen because one DataUnit depends on another (most depend on either Camera or SkyMap, for instance), or because a DataUnit (such as ObservedSensor) represents a join between others (such as Visit and PhysicalSensor).
    For example, if any of the following combinations of DataUnit types are used to initialize a DataUnitTypeSet, its elements will be ``[Camera, ObservedSensor, PhysicalSensor, Visit]``:

    - ``[Visit, PhysicalSensor]``
    - ``[ObservedSensor]``
    - ``[Visit, ObservedSensor, Camera]``
    - ``[Visit, PhysicalSensor, ObservedSensor]``

    .. py:method:: __init__(elements)

        Initialize the DataUnitTypeSet with a reordered and augmented version of the given DataUnit types as described above.

    .. py::method:: __iter__()

        Iterate over the DataUnit types in the set.

    .. py::method:: __len__()

        Return the number of DataUnit types in the set.

    .. py::method:: __getitem__(name)

        Return the DataUnit type with the given name.

    .. py::method:: pack(values)

        Compute an integer that uniquely identifies the given combination of
        :ref:`DataUnit` values.

        :param dict values: A dictionary that maps :ref:`DataUnit` type names to either the "values" of those units or actual :ref:`DataUnit` instances.

        :returns: a 64-bit unsigned :py:class:`int`.

        This method must be used to populate the ``unit_pack`` field in the :ref:``sql_Dataset table`.

    .. py::method:: expand(registry, values)

        Transform a dictionary of DataUnit instances from a dictionary of DataUnit "values" by querying the given :py:class:`Registry`.

        This can (and generally should) be used by concrete :ref:`Registries <Registry>` to implement :py:meth:`Registry.expand`, as it only uses :py:class:`Registry.query`.

.. todo::

    Where should we document the concrete DataUnit classes?
    They're closely related to common schema tables, but the Python API can't be inferred directly from the SQL declarations (and vice versa).


SQL Representation
------------------

There is one table for each :ref:`DataUnit` type, and a :ref:`DataUnit` instance is a row in one of those tables.
Being abstract, there is no single table associated with :ref:`DataUnits <DataUnit>` in general.

:ref:`DataUnits <DataUnit>` must be shared across different :ref:`Registries <Registry>`, so their primary keys must not be database-specific quantities such as autoincrement fields.

.. todo::

    Add links once Common Schema has link anchors for different tables.


.. _Collection:

Collection
==========

An entity that contains :ref:`Datasets <Dataset>`, with the following conditions:

- Has at most one :ref:`Dataset` per :ref:`DatasetRef`.
- Has a unique, human-readable identifier, called a CollectionTag.
- Can be combined with a :ref:`DatasetRef` to obtain a globally unique :ref:`URI`.

Transition
----------

The v14 Butler's Data Repository concept plays a similar role in many contexts, but with a very different implementation and a very different relationship to the :ref:`Registry` concept.

Python API
----------

CollectionTags are simply Python strings.

A :ref:`DataGraph` may be constructed to hold exactly the contents of a single :ref:`Collection`, but does not do so in general.

SQL Representation
------------------

Collections are defined by a pair of tables; the first simply contains the list of tags, and the second is a many-to-many join between it and the :ref:`Dataset table <sql_Dataset>`.

.. _sql_CollectionTag:

+-------------------+---------+-------------+
| *CollectionTag*                           |
+-------------------+---------+-------------+
| collection_tag_id | int     | PRIMARY KEY |
+-------------------+---------+-------------+
| name              | varchar | NOT NULL    |
+-------------------+---------+-------------+
| CONSTRAINT UNIQUE (name)                  |
+-------------------+---------+-------------+

.. _sql_DatasetCollectionTagJoin:

+-------------------+-----+-----------------------------------------------------------+
| *DatasetCollectionTagJoin*                                                          |
+===================+=====+===========================================================+
| collection_tag_id | int | PRIMARY KEY, REFERENCES CollectionTag (collection_tag_id) |
+-------------------+-----+-----------------------------------------------------------+
| dataset_id        | int | NOT NULL, REFERENCES Dataset (dataset_id)                 |
+-------------------+-----+-----------------------------------------------------------+

These tables should be present even in :ref:`Registries <Registry>` that only represent a single Collection (though in this case they may of course be trivial views).


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
        If not, a human-readable string identifier for the operation.
        Some :ref:`Registries <Registry>` may permit value to be None, but are not required to in general.

    .. py::attribute:: environment

        A description of the software environment and versions associated with the SuperTask instance in :py:attr:`task`, format TBD.

SQL Representation
------------------

Quantums are stored in a single table that records its scalar attributes:

 .. _sql_Quantum:

+-------------------------------------------------------------+
| *Quantum*                                                   |
+=================+=========+=================================+
| quantum_id      | int     | PRIMARY KEY                     |
+-----------------+---------+---------------------------------+
| task            | varchar |                                 |
+-----------------+---------+---------------------------------+
| config_id       | int     | REFERENCES Dataset (dataset_id) |
+-----------------+---------+---------------------------------+
| environment_id  | int     | REFERENCES Dataset (dataset_id) |
+-----------------+---------+---------------------------------+

Both the configuration (which is part of the :py:attr:`task attribute in Python <Quantum.task>` only if the task is a SuperTask, and absent otherwise ) and the environment are stored as standard :ref:`Datasets <Dataset>`.
This makes it impossible to query their values directly using a :ref:`Registry`, but it ensures that changes to the formats and content of these items do not require disruptive changes to the :ref:`Registry` schema.

The :ref:`Datasets <Dataset>` produced by a Quantum (the :py:attr:`Quantum.outputs` attribute in Python) is stored by the producer_id field in the :ref:`Dataset table <sql_Dataset>`.  The inputs, both predicted and actual, are stored in an additional join table:

.. _sql_DatasetConsumer:

+-------------+------+---------------------------------------------+
| *DatasetConsumer*                                                |
+=============+======+=============================================+
| quantum_id  | int  | NOT NULL REFERENCES Quantum (quantum_id)    |
+-------------+------+---------------------------------------------+
| dataset_id  | int  | NOT NULL REFERENCES Dataset (dataset_id)    |
+-------------+------+---------------------------------------------+
| actual      | bool | NOT NULL                                    |
+-------------+------+---------------------------------------------+

There is no guarantee that the full provenance of a :ref:`Dataset` is captured by these tables in all :ref:`Registries <Registry>`, because subset and transfer operations do not require provenace information to be included.  Furthermore, :ref:`Registries <Registry>` may or may not require a :ref:`Quantum` to be provided when calling :py:meth:`Registry.addDataset` (which is called by :py:meth:`Butler.put`), making it the callers responsibility to add provenance when needed.  However, all :ref:`Registries <Registry>` (including *limited* Registries) are required to record provenance information when it is provided.

.. note::

   As with everything else in the Common Schema, the provenance system used in the operations data backbone will almost certainly involve additional fields and tables, and what's in the Common Schema will just be a view.  But the provenance tables here are even more of a blind straw-man than the rest of the Common Schema (which is derived more directly from SuperTask requirements), and I certainly expect it to change based on feedback; I think this reflects all that we need outside the operations system, but how operations implements their system should probably influence the details.


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

A standard Uniform Resource Identifier pointing to a :ref:`InMemoryDataset` in a :ref:`Datastore`.

The :ref:`Dataset` pointed to may be **primary** or a component of a **composite**, but should always be serializable on its own.
When supported by the :ref:`Datastore` the query part of the URI (i.e. the part behind the optional question mark) may be used for slices (e.g. a region in an image).

.. todo::
    Datastore.get also accepts parameters for slices; is the above still true?

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

A storage hint provided to aid in constructing a :ref:`URI`.

Frequently (in e.g. filesystem-based Datastores) the path will be used as the full filename **within** a :ref:`Datastore`, and hence each :ref:`Dataset` in a :ref:`Registry` must have a unique path (even if they are in different :ref:`Collections <Collection>`).
This can only guarantee that paths are unique within a :ref:`Datastore` if a single :ref:`Registry` manages all writes to the :ref:`Datastore`.
Having a single :ref:`Registry` responsible for writes to a :ref:`Datastore` (even if multiple :ref:`Registries <Registry>` are permitted to read from it) is thus probably the easiest (but by no means the only) way to guarantee path uniqueness in a filesystem-basd :ref:`Datastore`.

Paths are generated from string templates, which are expanded using the :ref:`DataUnits <DataUnit>` associated with a :ref:`Dataset`, its :ref:`DatasetType` name, and the :ref:`Collection` the :ref:`Dataset` was originally added to.
Because a :ref:`Dataset` may ultimately be associated with multiple :ref:`Collections <Collection>`, one cannot infer the path for a :ref:`Dataset` that has already been added to a :ref:`Registry` from its template.
That means it is impossible to reconstruct a :ref:`URI` from the template, even if a particular :ref:`Datastore` guarantees a relationship between paths and :ref:`URIs <URI>`.
Instead, the original :ref:`URI` must be obtained by querying the :ref:`Registry`.

The actual :ref:`URI` used for storage is not required to respect the path (e.g. for object stores).


Transition
----------

The filled-in templates provided in Mapper policy files in the v14 Butler play the same role as the new :ref:`Path` concept when writing :ref:`Datasets <Dataset>`.
Mapper templates were also used in reading files in the v14 Butler, however, and :ref:`Paths <Path>` are not.

Python API
----------

Paths are represented by simple Python strings.

SQL Representation
------------------

Paths do not appear in SQL at all, but the defaults for the templates that generate them are a field in the :ref:`DatasetType table <sql_DatasetType>`.



.. _DatasetMetatype:

DatasetMetatype
===============

A category of :ref:`DatasetTypes <DatasetType>` that utilize the same in-memory classes for their :ref:`InMemoryDatasets <InMemoryDataset>` and can be saved to the same file format(s).


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

        Assemble a compound :ref:`InMemoryDataset`.

        Virtual method: must be implemented by derived classes.

        :param parent:
            An instance of the compound :ref:`InMemoryDataset` to be returned, or None.
            If no components are provided, this is the :ref:`InMemoryDataset` that will be returned.

        :param dict components: A dictionary whose keys are a subset of the keys in the :py:attr:`components` class attribute and whose values are instances of the component InMemoryDataset type.

        :param dict parameters: details TBD; may be used for slices of :ref:`Datasets <Dataset>`.

        :return: a :ref:`InMemoryDataset` matching ``parent`` with components replaced by those in ``components``.

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

A *limited* Registry implements only a small subset of the full Registry Python interface and has no SQL interface at all, and methods that would normally accept :py:class:`DatasetLabel` require a full :py:class:`DatasetRef` instead.
In general, limited Registries have enough functionality to support :py:meth:`Butler.get` and :py:meth:`Butler.put`, but no more.
A limited Registry may be implented on top of a simple persistent key-value store (e.g. a YAML file) rather than a full SQL database.
The operations supported by a limited Registry are indicated in the Python API section below.

Transition
----------

The v14 Butler's Mapper class contains a Registry object that is also implemented as a SQL database, but the new Registry concept differs in several important ways:

 - new Registries can hold multiple Collections, instead of being identified strictly with a single Data Repository;
 - new Registries also assume some of the responsibilities of the v14 Butler's Mapper;
 - new Registries have a much richer set of tables, permitting many more types of queries.

Python API
----------

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

        *For limited Registries, ``label`` must be a :py:class:`DatasetRef`, making this a guaranteed no-op (but still callable, for interface compatibility).*

    .. py:method:: find(tag, label)

        Look up the location of the :ref:`Dataset` associated with the given :py:class:`DatasetLabel`.

        This can be used to obtain the :ref:`URI` that permits the :ref:`Dataset` to be read from a :ref:`Datastore`.

        Must be a simple pass-through if ``label`` is already a :py:class:`DatasetHandle`.

        :param str tag: a :ref:`CollectionTag <Collection>` indicating the :ref:`Collection` to search.

        :param DatasetLabel label: a :py:class:`DatasetLabel` that identifies the :ref:`Dataset`.  *For limited Registries, must be a :py:class:`DatasetRef`.*

        :returns: a :py:class:`DatasetHandle` instance

    .. py:method:: makeDataGraph(tag, expr, datasetTypes) -> DataGraph

        Evaluate a :ref:`DatasetExpression` given a list of :ref:`DatasetTypes <DatasetType>` and return a :ref:`DataGraph`.

        :param str tag: a :ref:`CollectionTag <Collection>` indicating the :ref:`Collection` to search.

        :param str expr: a :ref:`DatasetExpression` that limits the :ref:`DataUnits <DataUnit>` and (indirectly) the :ref:`Datasets <Dataset>` returned.

        :param list[DatasetType] datasetTypes: the list of :ref:`DatasetTypes <DatasetType>` whose instances should be included in the graph.

        .. todo::
            Should we also supply a ``findAll`` or something to give you just a list
            of :ref:`Datasets <Dataset>`?  Or should the :ref:`DataGraph` be iterable
            (I guess it already is) such that one can loop over the results of a query
            and retrieve all relevant :ref:`Datasets <Dataset>`?

        :returns: a :ref:`DataGraph` instance

        *Not supported by limited Registries.*

    .. py:method:: subset(tag, expr, datasetTypes)

        Create a new :ref:`Collection` by subsetting an existing one.

        :param str tag: a :ref:`CollectionTag <Collection>` indicating the input :ref:`Collection` to subset.

        :param str expr: a :ref:`DatasetExpression` that limits the :ref:`DataUnits <DataUnit>` and (indirectly) the :ref:`Datasets <Dataset>` in the subset.

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

SQL Representation
------------------

A Registry provides an interface for querying the :ref:`CommonSchema`, and hence has no representation within that schema.


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

    .. py:method:: get(uri, parameters=None)

        Load a :ref:`InMemoryDataset` from the store.

        :param str uri: a :ref:`URI` that specifies the location of the stored :ref:`Dataset`.

        :param dict parameters: :ref:`DatasetMetatype`-specific parameters that specify a slice of the :ref:`Dataset` to be loaded.

        :returns: an :ref:`InMemoryDataset` or slice thereof.

    .. py:method:: put(inMemoryDataset, meta, path, typeName=None) -> URI, {name: URI}

        Write a :ref:`InMemoryDataset` with a given :ref:`DatasetMetatype` to the store.

        :param inMemoryDataset: the :ref:`InMemoryDataset` to store.

        :param DatasetMetatype meta: the :ref:`DatasetMetatype` associated with the :ref:`DatasetType`.

        :param str path: A :ref:`Path` that provides a hint that the :ref:`Datastore` may use as [part of] the :ref:`URI`.

        :param str typeName: The :ref:`DatasetType` name, which may be used by the :ref:`Datastore` to override the default serialization format for the :ref:`DatasetMetatype`.

        :returns: the :py:class:`str` :ref:`URI` and a dictionary of :ref:`URIs <URI>` for the :ref:`Dataset's <Dataset>` components.  The latter will be empty (or None?) if the :ref:`Dataset` is not a composite.

    .. py:method:: retrieve({URI (from) : URI (to)})

        Retrieves :ref:`Datasets <Dataset>` and stores them in the provided locations.
        Does not have to go through the process of creating a :ref:`InMemoryDataset`.

        .. todo::
            I'm not sure this interface will work; where will the output URIs come from, if not a Datastore?
            Maybe the dict values need to be paths?
            Or (meta, path, typeName) tuples, which might imply that the Datastore would sometimes have to change formats.

SQL Representation
------------------

Datastores are not represented in SQL at all.


.. _ButlerConfiguration:

ButlerConfiguration
===================

Configuration for :ref:`Butler`.

.. py:class:: ButlerConfiguration

    .. py:attribute:: inputCollection

        The :ref:`CollectionTag <Collection>` of the input collection.

    .. py:attribute:: outputCollection

        The :ref:`CollectionTag <Collection>` of the output collection.  May be the same as :py:attr:`inputCollection`.

    .. py:attribute:: templates

        A dict that maps :ref:`DatasetType` names to path templates, used to override :py:attr:`DatasetType.template` as obtained from the :ref:`Registry` when present.


.. _Butler:

Butler
======

A high level object that provides access to the :ref:`Datasets <Dataset>` in a single :ref:`Collection`.

Butlers hold and delegate most of their work to a :ref:`Registry` and a :ref:`Datastore`.


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

    .. py:method:: get(label, parameters=None)

        :param DatasetLabel label: a :py:class:`DatasetLabel` that identifies the :ref:`Dataset` to retrieve.

        :param dict parameters: a dictionary of :ref:`DatasetMetatype`-specific parameters that can be used to obtain a slice of the :ref:`Dataset`.

        :returns: an :ref:`InMemoryDataset`.

        Implemented as:

        .. code:: python

            try:
                handle = self.registry.find(self.config.inputCollection, label)
                parent = self.datastore.get(uri, handle.type.meta, parameters) if uri else None
                children = {name : self.datastore.get(childHandle, parameters) for name, childHandle in handle.components.items()}
                return handle.type.meta.assemble(parent, children, parameters)
            except NotFoundError:
                continue
            raise NotFoundError("DatasetRef {} not found in any input collection".format(datasetRef))

        .. todo::

            Implementation requires all components to be able to handle (typically pass-through)
            parameters passed for the composite.  Could we instead get away with only passing those
            when getting the parent from the :ref:`Datastore`?

        .. todo::

            Recursive composites were broken by a minor update.
            Would probably not be hard to add back in if we decide we need them, but they'd make the logic a bit harder to follow so not worth doing now.

    .. py:method:: put(label, dataset, producer)

        :param DatasetLabel label: a :py:class:`DatasetLabel` that will identify the :ref:`Dataset` being stored.

        :param dataset: the :ref:`InMemoryDataset` to store.

        :param Quantum producer: the :ref:`Quantum` instance that produced the :ref:`Dataset`.

        Implemented as:

        .. code:: python

            ref = self.registry.expand(label)
            template = self.config.templates.get(ref.type.name, None)
            path = ref.makePath(self.config.outputCollection, template)
            uri, components = self.datastore.put(inMemoryDataset, ref.type.meta, path, ref.type.name)
            self.registry.addDataset(self.config.outputCollection, ref, uri, components, quantum)

    .. todo::

        How much more of :ref:`Registry's <Registry>` should Butler forward.


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
These are different from :ref:`AbstractFilters <cs_table_AbstractFilter>`,
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



.. _sql_dataset_dataunit_joins:

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

