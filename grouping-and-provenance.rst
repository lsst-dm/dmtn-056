
Grouping and Provenance
=======================

.. _Collection:

Collection
----------

An entity that contains :ref:`Datasets <Dataset>`, with the following conditions:

- Has at most one :ref:`Dataset` per :ref:`DatasetRef`.
- Has a unique, human-readable identifier, called a CollectionTag.
- Can be combined with a :ref:`DatasetRef` to obtain a globally unique :ref:`URI`.

Transition
^^^^^^^^^^

The v14 Butler's Data Repository concept plays a similar role in many contexts, but with a very different implementation and a very different relationship to the :ref:`Registry` concept.

Python API
^^^^^^^^^^

CollectionTags are simply Python strings.

A :ref:`DataGraph` may be constructed to hold exactly the contents of a single :ref:`Collection`, but does not do so in general.

SQL Representation
^^^^^^^^^^^^^^^^^^

Collections are defined by a many-to-many "join" table that links :ref:`sql_Dataset` to CollectionTags.
Because CollectionTags are just strings, we have no independent Collection table.

.. _sql_DatasetCollectionJoin:

DatasetCollections
""""""""""""""""""
Fields:
    +-------------+---------+----------+
    | tag         | varchar | NOT NULL |
    +-------------+---------+----------+
    | dataset_id  | int     | NOT NULL |
    +-------------+---------+----------+
    | registry_id | int     | NOT NULL |
    +-------------+---------+----------+
Primary Key:
    None
Foreign Keys:
    - (dataset_id, registry_id) references :ref:`sql_Dataset` (dataset_id, registry_id)


This tables should be present even in :ref:`Registries <Registry>` that only represent a single Collection (though in this case it may of course be a trivial views on :ref:`sql_Dataset`).

.. todo::

    Storing the tag name for every :ref:`Dataset` is costly (but may be mitigated by compression).
    Perhaps better to have a separate :ref:`Collection` table and reference by ``collection_id`` instead?

.. _Run:

Run
---

An action that produces :ref:`Datasets <Dataset>`, usually associated with a well-defined software environment.

Most Runs will correspond to a launch of a SuperTask Pipeline.

Transition
^^^^^^^^^^

A Run is at least initially associated with a :ref:`Collection`, making it (like :ref:`Collection`) similar to the v14 Data Repository concept.  Again like :ref:`Collection` its implementation is entirely different.

Python API
^^^^^^^^^^

.. py:class:: Run

    A concrete, final class representing a Run.

    .. py:method:: __init__(self, tag, environment=None)

        Initialize the Run with the given :ref:`Collection` tag and optional environment :py:class:`DatasetHandle`.

    .. py:attribute:: tag

        The :ref:`Collection` tag associated with a Run.
        While a new tag is created for a Run when the Run is created, that tag may later be deleted, so this attribute may be None.

    .. py::attribute:: environment

        A :py:class:`DatasetHandle` that can be used to retreive a description of the software environment used to create the Run.

    .. py::attribute:: pkey

        The ``(run_id, registry_id)`` tuple used to uniquely identify this Run, or ``None`` if it has not yet been inserted into a :ref:`Registry`.

SQL Representation
^^^^^^^^^^^^^^^^^^

.. _sql_Run:

Run
"""
Fields:
    +---------------------+---------+----------+
    | run_id              | int     | NOT NULL |
    +---------------------+---------+----------+
    | registry_id         | int     | NOT NULL |
    +---------------------+---------+----------+
    | tag                 | varchar |          |
    +---------------------+---------+----------+
    | environment_id      | int     | NOT NULL |
    +---------------------+---------+----------+
Primary Key:
    run_id, registry_id
Foreign Keys:
    - (environment_id, registry_id) references :ref:`sql_Dataset` (dataset_id, registry_id)

Run uses the same compound primary key approach as :ref:`sql_Dataset`.

.. _Quantum:

Quantum
-------

A discrete unit of work that may depend on one or more :ref:`Datasets <Dataset>` and produces one or more :ref:`Datasets <Dataset>`.

Most Quanta will be executions of a particular SuperTask's ``runQuantum`` method, but they can also be used to represent discrete units of work performed manually by human operators or other software agents.

Transition
^^^^^^^^^^

The Quantum concept does not exist in the v14 Butler.

A Quantum is analogous to an Open Provenance Model "process".

Python API
^^^^^^^^^^

.. py:class:: Quantum

    .. py:attribute:: run

        The :py:class:`Run` this Quantum is a part of.

    .. py:attribute:: predictedInputs

        A dictionary of input datasets that were expected to be used, with :ref:`DatasetType` names as keys and a :py:class:`set` of :py:class:`DatasetRef` instances as values.

        Input :ref:`Datasets <Dataset>` that have already been stored may be :py:class:`DatasetHandles <DatasetHandle>`, and in many contexts may be guaranteed to be.

        Read only; update via :py:meth:`addInput`.

    .. py:attribute:: actualInputs

        A dictionary of input datasets that were actually used, with the same form as :py:attr:`predictedInputs`.

        All returned sets must be subsets of those in :py:attr:`predictedInputs`.

        Read only; update via :py:meth:`addInput`.

    .. py:method:: addInput(ref, actual=True)

        Add an input :ref:`DatasetRef` to the :ref:`Quantum`.

        This does not automatically update a :ref:`Registry`.

        .. todo::

            How do we synchronize in-memory Quanta with those in a Registry?
            Need to work through the SuperTask use cases, probably.

    .. py:attribute:: outputs

        A dictionary of output datasets, with the same form as :py:attr:`predictedInputs`.

        Read-only; update via :py:meth:`Registry.addDataset`, :py:meth:`DataGraph.addDataset`, or :py:meth:`Butler.put`.

    .. py:attribute:: task

        If the Quantum is associated with a SuperTask, this is the SuperTask instance that produced and should execute this set of inputs and outputs.
        If not, a human-readable string identifier for the operation.
        Some :ref:`Registries <Registry>` may permit value to be None, but are not required to in general.

    .. py::attribute:: pkey

        The ``(quantum_id, registry_id)`` tuple used to uniquely identify this Run, or ``None`` if it has not yet been inserted into a :ref:`Registry`.


SQL Representation
^^^^^^^^^^^^^^^^^^

Quanta are stored in a single table that records its scalar attributes:

 .. _sql_Quantum:

Quantum
"""""""
Fields:
    +-----------------+---------+----------+
    | quantum_id      | int     | NOT NULL |
    +-----------------+---------+----------+
    | registry_id     | int     | NOT NULL |
    +-----------------+---------+----------+
    | run_id          | int     | NOT NULL |
    +-----------------+---------+----------+
    | task            | varchar |          |
    +-----------------+---------+----------+
    | config_id       | int     |          |
    +-----------------+---------+----------+
Primary Key:
    quantum_id, registry_id
Foreign Keys:
    - (run_id, registry_id) references :ref:`sql_Run` (run_id, registry_id)
    - (config_id, registry_id) references :ref:`sql_Dataset` (dataset_id, registry_id)

Run uses the same compound primary key approach as :ref:`sql_Dataset`.

The configuration (which is part of the :py:attr:`task attribute in Python <Quantum.task>` only if the task is a SuperTask, and absent otherwise ) is stored as a standard :ref:`Datasets <Dataset>`.
This makes it impossible to query its values directly using a :ref:`Registry`, but it ensures that changes to its formats and content of these items do not require disruptive changes to the :ref:`Registry` schema.

Quantum uses the same compound primary key approach as :ref:`sql_Dataset`.

The :ref:`Datasets <Dataset>` produced by a Quantum (the :py:attr:`Quantum.outputs` attribute in Python) is stored in the producer_id field in the :ref:`Dataset table <sql_Dataset>`.
The inputs, both predicted and actual, are stored in an additional join table:

.. _sql_DatasetConsumers:

Fields:
    +---------------------+------+----------+
    | quantum_id          | int  | NOT NULL |
    +---------------------+------+----------+
    | quantum_registry_id | int  | NOT NULL |
    +---------------------+------+----------+
    | dataset_id          | int  | NOT NULL |
    +---------------------+------+----------+
    | dataset_registry_id | int  | NOT NULL |
    +---------------------+------+----------+
    | actual              | bool | NOT NULL |
    +---------------------+------+----------+
Primary Key:
    None
Foreign Keys:
    - (quantum_id, quantum_registry_id) references :ref:`sql_Quantum` (quantum_id, registry_id)
    - (dataset_id, dataset_registry_id) references :ref:`sql_Dataset` (dataset_id, registry_id)


There is no guarantee that the full provenance of a :ref:`Dataset` is captured by these tables in all :ref:`Registries <Registry>`, because subset and transfer operations do not require provenance information to be included.  Furthermore, :ref:`Registries <Registry>` may or may not require a :ref:`Quantum` to be provided when calling :py:meth:`Registry.addDataset` (which is called by :py:meth:`Butler.put`), making it the callers responsibility to add provenance when needed.
However, all :ref:`Registries <Registry>` (including *limited* Registries) are required to record provenance information when it is provided.

.. note::

   As with everything else in the common Registry schema, the provenance system used in the operations data backbone will almost certainly involve additional fields and tables, and what's in the schema will just be a view.  But the provenance tables here are even more of a blind straw-man than the rest of the schema (which is derived more directly from SuperTask requirements), and I certainly expect it to change based on feedback; I think this reflects all that we need outside the operations system, but how operations implements their system should probably influence the details.
