##################
Preflight Redesign
##################

This section describes an alternative approach to the :ref:`Preflight` problem in which the per-SuperTask calculation of the quanta to be executed is performed by a declarative SQL expression instead of an imperative Python method (i.e. ``SuperTask.defineQuanta``).

This should reduce code duplication across SuperTasks by moving logic into the shared Preflight Solver, essentially eliminate the need for ORM-like DataUnit objects in Python, and provide more flexibility for operators who with to override the default SuperTask behavior.


Preflight Interface
===================



Registry Design Implications
============================

Because all grouping and filtering operations on :ref:`DataUnits <DataUnit>` are performed in SQL in this design (and :reF:`Preflight` was previously the only driver for :ref:`DataUnit` filtering and grouping in Python), this design should permit us to significantly simplify the representation of :ref:`DataUnits <DataUnit>` in Python.  This includes

 - All current Python :ref:`DataUnit` classes will be removed.  We expect to instead have a hierarchy of classes whose instances represent :ref:`DataUnit` *tables* rather than the rows of those tables.  We will instead typically use plain ``dict`` objects (called DataIDs by analogy with the Gen. 2 Butler concept) to represent the rows of :ref:`DataUnit` tables.

 - :py:class:`DataUnitMap` class will be completely removed.

 - :py:class:`DataUnitTypeSet` will be renamed to ``DataUnitSet``, since `DataUnit` instances rather than types now represent tables.

 - :py:meth:`Registry.addDataUnit's <Registry.addDataUnit>` signature will change to accept one of the new :ref:`DataUnit` table objects and a sequence of ``dicts``, allowing it to add multiple :ref:`DataUnit` rows in a single call.

 - :py:meth:`Registry.findDataUnit` will be completely removed.

 - :py:meth:`Registry.makeDataGraph` will be completely removed.

 - :py:meth:`Registry.expand` and :py:meth:`Registry.find` will modify their input :py:class:`DatasetRef2` arguments in-place and then return them.

 - :py:meth:`Registry.expand` will take additional optional arguments specifying additional fields to read into the :py:class:`DatasetRef`.

 - The :py:class:`DatasetLabel` / :py:class:`DatasetRef` / :py:class:`DatasetHandle` class hierarchy will be collapsed to a single :py:class:`DatasetRef2` class:

.. py:class:: DatasetRef2

    A reference to a Dataset that may exist in a Registry.

    (Will be renamed to "DatasetRef" instead of "DatasetRef2"; the trailing underscore is for disambiguation with the current class.)

    DatasetRef is not immutable, but it is "append-only": it can never be modified to point to a different Dataset, but additional data about the Dataset may be added by a :ref:`Registry`.  Because DatasetRef comparisons are based only on the information that must be provided by construction, this is sufficient for them to be considered hashable and hence usable as keys in ``dicts`` and ``sets``.

    .. py:method:: __init__(self, type, id):

        Construct from a :py:class:`DatasetType` instance and Data ID ``dict``.

    .. py:attribute:: type

        Read-only instance attribute.

        The :py:class:`DatasetType` associated with the :ref:`Dataset` the DatasetRef points to.

    .. py:attribute:: id

        Read-only instance attribute.

        A read-only view to a ``dict`` containing the values of the DataUnits associated with this Dataset.

        Dictionary keys may be the names of DataUnit tables (e.g. "Visit"), or dot-separated names of fields within them (e.g. "Visit.exposure_time").  The name of a table is interpreted as the name of the "value" field for that table (e.g. "Visit" is interpreted as "Visit.number").

        The ID will always contain enough entries to fully specify the primary key of all DataUnits in the associated DatasetType, and will contain additional entries only when explicitly requested.

    .. py:attribute:: producer

        The :py:class:`Quantum` instance that produced (or will produce) the :ref:`Dataset`.

        Read-only instance attribute; producers can be added via :py:meth:`Registry.addDataset`, :py:meth:`QuantumGraph.addDataset`, or :py:meth:`Butler.put`, while existing provenance can be retrieved via :py:meth:`Registry.expand`.

        May be None.

    .. py:attribute:: predictedConsumers

        A sequence of :py:class:`Quantum` instances that list this :ref:`Dataset` in their :py:attr:`predictedInputs <Quantum.predictedInputs>` attributes.

        Read-only instance attribute; update via :py:meth:`Quantum.addPredictedInput`, or retrieve existing provenance via :py:meth:`Registry.expand`.

        May be None.

    .. py:attribute:: actualConsumers

        A sequence of :py:class:`Quantum` instances that list this :ref:`Dataset` in their :py:attr:`actualInputs <Quantum.actualInputs>` attributes.

        Read-only instance attribute; update via :py:meth:`Registry.markInputUsed`, or retrieve existing provenance via :py:meth:`Registry.expand`.

        May be None.

    .. py:attribute:: uri

        Read-only instance attribute.

        The :ref:`URI` that holds the location of the :ref:`Dataset` in a :ref:`Datastore`.  Can be set by calling :py:meth:`Registry.find`.

        May be None if the DatasetRef2 is not yet associated with an existing :ref:`Dataset`.

    .. py:attribute:: components

        Read-only instance attribute.

        A :py:class:`dict` holding :py:class:`DatasetRef2` instances that correspond to this :ref:`Dataset's <Dataset>` named components.

        Can be set by calling :py:meth:`Registry.find`.

        Empty if the :ref:`Dataset` is not a composite.  May be None if the DatasetRef2 is not yet associated with an existing :ref:`Dataset`

    .. py:attribute:: run

        Read-only instance attribute.

        Can be set by calling :py:meth:`Registry.find`.

        The :ref:`Run` the :ref:`Dataset` was created with.

        May be None if the DatasetRef2 is not yet associated with an existing :ref:`Dataset`

    .. py:method:: makeStorageHint(run, template=None) -> StorageHint

        Construct the :ref:`StorageHint` part of a :ref:`URI` by filling in ``template`` with the :ref:`Run` and the values in the :py:attr:`id` dict.

        This is often just a storage hint since the :ref:`Datastore` will likely have to deviate from the provided storageHint (in the case of an object-store for instance).

        Although a :ref:`Dataset` may belong to multiple :ref:`Collections <Collection>`, only the :ref:`Collection` associated with its :ref:`Run` is used in its :ref:`StorageHint`.

        :param Run run: the :ref:`Run` to which the new :ref:`Dataset` will be added; always implies a collection :ref:`Collection` that can also be used in the template.

        :param str template: a storageHint template to fill in.  If None, the :py:attr:`template <DatasetType.template>` attribute of :py:attr:`type` will be used.

        :returns: a str :ref:`StorageHint`
