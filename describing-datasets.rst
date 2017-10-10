
Describing Datasets
===================

.. _Dataset:

Dataset
-------

A Dataset is a discrete entity of stored data, possibly with associated metadata.

Datasets are uniquely identified by either a :ref:`URI` or the combination of a :ref:`CollectionTag <Collection>` and a :ref:`DatasetRef`.

Example: a "calexp" for a single visit and sensor produced by a processing run.

A Dataset may be *composite*, which means it contains one or more named *component* Datasets.
Composites may be stored either by storing the parent in a single file or by storing the components separately.
Some composites simply aggregate that are always written as part of other :ref:`Datasets <Dataset>`, and are themselves read-only.

Datasets may also be *sliced*, which yields an :ref:`InMemoryDataset` of the same type containing a smaller amount of data, defined by some parameters.
Subimages and filters on catalogs are both considered slices.

Transition
^^^^^^^^^^

The Dataset concept has essentially the same meaning that it did in the v14 Butler.

A Dataset is analogous to an Open Provenance Model "artifact".

Python API
^^^^^^^^^^

The Python representation of a :ref:`Dataset` is in some sense a :ref:`InMemoryDataset`, and hence we have no Python "Dataset" class.
However, we have several Python objects that act like pointers to :ref:`Datasets <Dataset>`.
These are described in the Python API section for :ref:`DatasetRef`.

SQL Representation
^^^^^^^^^^^^^^^^^^

Datasets are represented by records in a single table that includes everything in a :ref:`Registry`, regardless of :ref:`Collection` or :ref:`DatasetType`:

.. _sql_Dataset:

Dataset
"""""""
Fields:
    +---------------------+---------+----------+
    | dataset_id          | int     | NOT NULL |
    +---------------------+---------+----------+
    | registry_id         | int     | NOT NULL |
    +---------------------+---------+----------+
    | dataset_type_name   | int     | NOT NULL |
    +---------------------+---------+----------+
    | unit_pack           | binary  | NOT NULL |
    +---------------------+---------+----------+
    | uri                 | varchar |          |
    +---------------------+---------+----------+
    | run_id              | int     | NOT NULL |
    +---------------------+---------+----------+
    | producer_id         | int     |          |
    +---------------------+---------+----------+
Primary Key:
    dataset_id, registry_id
Foreign Keys:
    - dataset_type_name references :ref:`sql_DatasetType` (name)
    - (run_id, registry_id) references :ref:`sql_Run` (run_id, registry_id)
    - (producer_id, registry_id) references :ref:`sql_Quantum` (quantum_id, registry_id)

Using a single table (instead of per-:ref:`DatasetType` and/or per-:ref:`Collection` tables) ensures that table-creation permissions are not required when adding new :ref:`DatasetTypes <DatasetType>` or :ref:`Collections <Collection>`.  It also makes it easier to store provenance by associating :ref:`Datasets <Dataset>` with :ref:`Quanta <Quantum>`.

The disadvantage of this approach is that the connections between :ref:`Datasets <Dataset>` and :ref:`DataUnits <DataUnit>` must be stored in a set of :ref:`additional join tables <sql_dataset_dataunit_joins>` (one for each :ref:`DataUnit` table).
The connections are summarized by the ``unit_pack`` field, which contains an ID that is unique only within a :ref:`Collection` for a given :ref:`DatasetType`, constructed by bit-packing the values of the associated units (a :ref:`Path` would be a viable but probably inefficient choice).
While a ``unit_pack`` value cannot be used to reconstruct a full :ref:`DatasetRef`, a ``unit_pack`` value can be used to quickly search for the :ref:`Dataset` matching a given :ref:`DatasetRef`.
It also allows :py:meth:`Registry.merge` to be implemented purely as a database operation by using it as a GROUP BY column in a query over multiple :ref:`Collections <Collection>`.

Dataset utilizes a compound primary key that combines an autoincrement ``dataset_id`` field that is populated by the :ref:`Registry` in which the :ref:`Dataset` originated and a ``registry_id`` that identifies that :ref:`Registry`.
When transferred between :ref:`Registries <Registry>`, the ``registry_id`` should be transferred without modification, allowing new :ref:`Datasets <Dataset>` to be assigned ``dataset_id`` values that were used or may be used in the future in the transferred-from :ref:`Registry`.

.. _sql_DatasetComposition:

DatasetComposition
^^^^^^^^^^^^^^^^^^
Fields:
    +-------------------------+---------+----------+
    | parent_dataset_id       | int     | NOT NULL |
    +-------------------------+---------+----------+
    | parent_registry_id      | int     | NOT NULL |
    +-------------------------+---------+----------+
    | component_dataset_id    | int     | NOT NULL |
    +-------------------------+---------+----------+
    | component_registry_id   | int     | NOT NULL |
    +-------------------------+---------+----------+
    | component_name          | varchar | NOT NULL |
    +-------------------------+---------+----------+
Primary Key:
    None
Foreign Keys:
    - (parent_dataset_id, parent_registry_id) references :ref:`sql_Dataset` (dataset_id, registry_id)
    - (component_dataset_id, component_registry_id) references :ref:`sql_Dataset` (dataset_id, registry_id)

A self-join table that links composite datasets to their components.

* If a virtual :ref:`Dataset` was created by writing multiple component Datasets, the parent :ref:`DatasetType's <sql_DatasetType>` ``template`` field and the parent Dataset's ``uri`` field may be null (depending on whether there was also a parent Dataset stored whose components should be overridden).

* If a single :ref:`Dataset` was written and we're defining virtual components, the component :ref:`DatasetTypes <sql_DatasetType>` should have null ``template`` fields, but the component Datasets will have non-null ``uri`` fields with values returned by the :ref:`Datastore` when :py:meth:`Datastore.put` was called on the parent.

.. _DatasetType:

DatasetType
-----------

A named category of :ref:`Datasets <Dataset>` that defines how they are organized, related, and stored.

In addition to a name, a DatasetType includes:

 - a template string that can be used to construct a :ref:`Path` (may be overridden);
 - a tuple of :ref:`DataUnit <DataUnit>` types that define the structure of :ref:`DatasetRefs <DatasetRef>`;
 - a :ref:`StorageClass` that determines how :ref:`Datasets <Dataset>` are stored and composed.

Transition
^^^^^^^^^^

The DatasetType concept has essentially the same meaning that it did in the v14 Butler.

Python API
^^^^^^^^^^

.. py:class:: DatasetType

    A concrete, final class whose instances represent :ref:`DatasetTypes <DatasetType>`.

    DatasetType instances may be constructed without a :ref:`Registry`, but they must be registered via :py:meth:`Registry.registerDatasetType` before corresponding :ref:`Datasets <Dataset>` may be added.

    DatasetType instances are immutable.

    .. note::

        In the current design, :py:class:`DatasetTypes <DatasetType>` are not type objects, and the :py:class:`DatasetRef` class is not an instance of :py:class:`DatasetType`.
        We could make that the case with a lot of metaprogramming, but this adds a lot of complexity to the code with no obvious benefit.
        It seems most prudent to just rename the :ref:`DatasetType` concept and class to something that doesn't imply a type-instance relationship in Python.

    .. py:method:: __init__(name, template, units, storageClass)

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

    .. py:attribute:: storageClass

        Read-only instance attribute.

        A :py:class:`StorageClass` subclass (not instance) that defines how this :ref:`DatasetType` is persisted.

SQL Representation
^^^^^^^^^^^^^^^^^^

DatasetTypes are stored in a :ref:`Registry` using two tables.
The first has a single record for each DatasetType and contains most of the information that defines it:

.. todo::

    I'm a bit worried about relying on ``name`` being globally unique across :ref:`Registries <Registry>`, but clashes should be very rare, and it might be good from a confusion-avoidance standpoint to force people to use new names when they mean something different.

.. _sql_DatasetType:

DatasetType
"""""""""""
Fields:
    +-----------------------+---------+----------+
    | name                  | varchar | NOT NULL |
    +-----------------------+---------+----------+
    | template              | varchar |          |
    +-----------------------+---------+----------+
    | storage_class         | varchar | NOT NULL |
    +-----------------------+---------+----------+
Primary Key:
    name
Foreign Keys:
    None

The second table has a many-to-one relationship with the first and holds the names of the :ref:`DataUnit` types utilized by its :ref:`DatasetRefs <DatasetRef>`:

.. _sql_DatasetTypeUnits:

DatasetTypeUnits
""""""""""""""""
Fields:
    +-------------------------+---------+----------+
    | dataset_type_name       | varchar | NOT NULL |
    +-------------------------+---------+----------+
    | unit_name               | varchar | NOT NULL |
    +-------------------------+---------+----------+
Primary Key:
    None
Foreign Keys:
    - (dataset_type_name) references :ref:`sql_DatasetType` (name)

.. _StorageClass:

StorageClass
---------------

A category of :ref:`DatasetTypes <DatasetType>` that utilize the same in-memory classes for their :ref:`InMemoryDatasets <InMemoryDataset>` and can be saved to the same file format(s).


Transition
^^^^^^^^^^

The allowed values for "storage" entries in v14 Butler policy files are analogous to StorageClasss.

Python API
^^^^^^^^^^

.. py:class:: StorageClass

    An abstract base class whose subclasses are :ref:`StorageClasss <StorageClass>`.

    .. py:attribute:: subclasses

        Concrete class attribute: provided by the base class.

        A dictionary holding all :py:class:`StorageClass` subclasses,
        keyed by their :py:attr:`name` attributes.

    .. py:attribute:: name

        Virtual class attribute: must be provided by derived classes.

        A string name that uniquely identifies the derived class.

    .. py:attribute:: components

        Virtual class attribute: must be provided by derived classes.

        A dictionary that maps component names to the :py:class:`StorageClass` subclasses for those components.
        Should be empty (or ``None``?) if the :ref:`StorageClass` is not a composite.

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
^^^^^^^^^^^^^^^^^^

The :ref:`DatasetType table <sql_DatasetType>` holds StorageClass names in a ``varchar`` field.
As a name is sufficient to retreive the rest of the StorageClass definition in Python, the additional information is not duplicated in SQL.

.. _DatasetRef:

DatasetRef
----------

An identifier for a :ref:`Dataset` that can be used across different :ref:`Collections <Collection>` and :ref:`Registries <Registry>`.
A :ref:`DatasetRef` is effectively the combination of a :ref:`DatasetType` and a tuple of :ref:`DataUnits <DataUnit>`.

Transition
^^^^^^^^^^

The v14 Butler's DataRef class played a similar role.

The :py:class:`DatasetLabel` class also described here is more similar to the v14 Butler Data ID concept, though (like DatasetRef and DataRef, and unlike Data ID) it also holds a :ref:`DatasetType` name).

Python API
^^^^^^^^^^

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
A :py:class:`DatasetRef` instance cannot be constructed without complete :ref:`DataUnits <DataUnit>` and a complete :ref:`DatasetType`, making it somewhat more cumbersome to use in interactive contexts.
The SuperTask pattern hides those extra construction steps from both SuperTask authors and operators, however, and :py:class:`DatasetRef` is the class SuperTask authors will use most.

Instances of the final class in the hierarchy, :py:class:`DatasetHandle`, always correspond to a :ref:`Datasets <Dataset>` that has already been stored in a :ref:`Datastore`.
A :py:class:`DatasetHandle` instance cannot be constructed without interacting directly with a :ref:`Registry`.
In addition to the :ref:`DataUnits <DataUnit>` and :ref:`DatasetType` exposed by :py:class:`DatasetRef`, a :py:class:`DatasetHandle` also provides access to its :ref:`URI` and component :ref:`Datasets <Dataset>`.
The additional functionality provided by :py:class:`DatasetHandle` is rarely needed unless one is interacting directly with a :py:class:`Registry` or :py:class:`Datastore` (instead of a :py:class:`Butler`), but the :py:class:`DatasetRef` instances that appear in SuperTask code may actually be :py:class:`DatasetHandle` instances (in a language other than Python, this would have been handled as a :py:class:`DatasetRef` pointer to a :py:class:`DatasetHandle`, ensuring that the user sees only the :py:class:`DatasetRef` interface, but Python has no such concept).

All three classes are immutable.

.. py:class:: DatasetLabel

    .. py:method:: __init__(self, name, **units)

        Construct a DatasetLabel from the name of a :ref:`DatasetType` and a keyword arguments providing :ref:`DataUnit` key-value pairs.

.. py:class:: DatasetRef(DatasetLabel)

    .. py:method:: __init__(self, type, units):

        Construct a DatasetRef from a :py:class:`DatasetType` and a complete tuple of :py:class:`DataUnits <DataUnit>`.

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

    .. py:attribute:: producer

        The :py:class:`Quantum` instance that produced (or will produce) the :ref:`Dataset`.

        Read-only; update via :py:meth:`Registry.addDataset`, :py:meth:`DataGraph.addDataset`, or :py:meth:`Butler.put`.

        May be None.

    .. py:attribute:: predictedConsumers

        A sequence of :py:class:`Quantum` instances that list this :ref:`Dataset` in their :py:attr:`predictedInputs <Quantum.predictedInputs>` attributes.

        Read-only; update via :py:meth:`Quantum.addInput`.

        May be None.

    .. py:attribute:: actualConsumers

        A sequence of :py:class:`Quantum` instances that list this :ref:`Dataset` in their :py:attr:`actualInputs <Quantum.actualInputs>` attributes.

        Read-only; update via :py:meth:`Quantum.addInput`.

        May be None.

.. py:class:: DatasetHandle(DatasetRef)

    .. py:attribute:: uri

        Read-only instance attribute.

        The :ref:`URI` that holds the location of the :ref:`Dataset` in a :ref:`Datastore`.

    .. py:attribute:: components

        Read-only instance attribute.

        A :py:class:`dict` holding :py:class:`DatasetHandle` instances that correspond to this :ref:`Dataset's <Dataset>` named components.

        Empty (or ``None``?) if the :ref:`Dataset` is not a composite.


SQL Representation
^^^^^^^^^^^^^^^^^^

As discussed in the description of the :ref:`Dataset` SQL representation, the :ref:`DataUnits <DataUnit>` in a :ref:`DatasetRefs <DatasetRef>` are related to :ref:`Datasets <Dataset>` by a :ref:`set of join tables <sql_dataset_dataunit_joins>`.
Each of these connects the :ref:`Dataset table's <sql_Dataset>` ``dataset_id`` to the primary key of a concrete :ref:`DataUnit` table.

.. _InMemoryDataset:

InMemoryDataset
---------------

The in-memory manifestation of a :ref:`Dataset`

Example: an ``afw.image.Exposure`` instance with the contents of a particular ``calexp``.

Transition
^^^^^^^^^^

The "python" and "persistable" entries in v14 Butler dataset policy files refer to Python and C++ InMemoryDataset types, respectively.

.. _Path:

Path
----

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
^^^^^^^^^^

The filled-in templates provided in Mapper policy files in the v14 Butler play the same role as the new :ref:`Path` concept when writing :ref:`Datasets <Dataset>`.
Mapper templates were also used in reading files in the v14 Butler, however, and :ref:`Paths <Path>` are not.

Python API
^^^^^^^^^^

Paths are represented by simple Python strings.

SQL Representation
^^^^^^^^^^^^^^^^^^

Paths do not appear in SQL at all, but the defaults for the templates that generate them are a field in the :ref:`DatasetType table <sql_DatasetType>`.


.. _URI:

URI
---

A standard Uniform Resource Identifier pointing to a :ref:`InMemoryDataset` in a :ref:`Datastore`.

The :ref:`Dataset` pointed to may be **primary** or a component of a **composite**, but should always be serializable on its own.
When supported by the :ref:`Datastore` the query part of the URI (i.e. the part behind the optional question mark) may be used for slices (e.g. a region in an image).

.. todo::
    Datastore.get also accepts parameters for slices; is the above still true?

Transition
^^^^^^^^^^

No similar concept exists in the v14 Butler.

Python API
^^^^^^^^^^

We can probably assume a URI will be represented as a simple string initially.

It may be useful to create a class type to enforce grammar and/or provide convenience operations in the future.


SQL Representation
^^^^^^^^^^^^^^^^^^

URIs are stored as a field in the :ref:`Dataset table <sql_Dataset>`.


.. _DataGraph:

DataGraph
---------

A graph in which the nodes are :ref:`DatasetRefs <DatasetRef>` and :ref:`DataUnits <DataUnit>` and/or :ref:`Quanta <Quantum>`, and the edges are the relations between them.

Python API
^^^^^^^^^^

.. py:class:: DataGraph

    .. py:attribute:: datasets

        A dictionary with :ref:`DatasetType` names as keys and sets of :py:class:`DatasetRefs <DatasetRef>` of those types as values.

        Read-only (possibly only by convention); use :py:meth:`addDataset` to insert new :py:class:`DatasetRefs <DatasetRef>`.

    .. py:attribute:: quanta

        A sequence of :py:class:`Quantum` instances whose order is consistent with their dependency ordering.

        Read-only (possibly only by convention); use :py:meth:`addQuantum` to insert new :py:class:`Quantums <Quantum>`.

    .. py:method:: addQuantum(quantum)

        Add a :py:class:`Quantum` to the graph.

        Any entries in :py:attr:`Quantum.predictedInputs` or :py:attr:`Quantum.actualInputs` must already be present in the graph.
        The :py:attr:`Quantum.outputs` attribute should be empty.

    .. py:method:: addDataset(ref, producer)

        Add a :py:class:`DatasetRef` to the graph.

        :param DatasetRef ref: a pointer to the :ref:`Dataset` to be added.

        :param Quantum producer: the :py:class:`Quantum` responsible for producing the :ref:`Dataset`.

    .. py:method:: findDataUnit(cls, pkey)

        Return a :ref:`DataUnit` given the values of its primary key.

        :param type cls: a class that inherits from :py:class:`DataUnit`.

        :param tuple pkey: a tuple of primary key values that uniquely identify the :ref:`DataUnit`; see :py:attr:`DataUnit.pkey`.

        :returns: a :py:class:`DataUnit` instance of type ``cls``, or ``None`` if no matching unit is found in the graph.

        See also :py:meth:`Registry.findDataUnit`.

    .. py:method:: relate(unitTypes)

        Iterate over tuples of :py:class:`DataUnits <DataUnit>` related by dependency and many-to-many relationships.

        :param DataUnitTypeSet unitTypes: a tuple of :py:class:`DataUnit` (subclass) instances.

        :returns: an iterator over tuples of :ref:`DataUnit` (subclass) instances.

        .. todo::

            Implementing this method will require DataGraph to have more state than just the :py:attr:`datasets` and :py:attr:`quanta` attributes.
            The extra state I have in mind is a table containing all of the :ref:`DataUnit` values for the :ref:`DataUnit` types included in the graph (which will include lots of NULLs, of course).
            That's the natural result of the SQL that :py:meth:`Registry.makeDataGraph`, which works out perfectly for the SuperTask Preflight use case.
            But we don't have an easy way to make that table when we instead construct a DataGraph to report the provenance of existing :ref:`Datasets <Dataset>`, and I'm inclined to just let the method throw in that case.
            A slightly cleaner but more verbose option would be to return to having two completely distinct graph classes.
