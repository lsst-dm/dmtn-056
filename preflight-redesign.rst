##################
Preflight Redesign
##################

This section describes an alternative approach to the :ref:`Preflight` problem in which the per-SuperTask calculation of the quanta to be executed is performed by a declarative SQL expression instead of an imperative Python method (i.e. ``SuperTask.defineQuanta``).

This should reduce code duplication across SuperTasks by moving logic into the shared Preflight Solver, essentially eliminate the need for ORM-like DataUnit objects in Python, and provide more flexibility for operators who wish to override the default SuperTask behavior.


SuperTask Design Implications
=============================

Because we put the declarative information in the SuperTask's configuration instead of its class body, we also gain considerable flexibility in how a particular SuperTask is executed; the same concrete SuperTask could now be used, for instance, to do a scatter and/or gather operation between Visits and ObservedSensors or between Tracts and Patches.

Finally, the new Preflight solver algorithm will require access only to that configuration instead of an instantiated SuperTask.  This actually avoids the need to do any SuperTask instantiation when the QuantumGraph is being determined.
We will still in general need to instantiate all SuperTasks in a Pipeline before any are executed (to allow one SuperTask to depend on the schemas computed by its predecessors, and to do this consistenly and without races), but we now have much more flexibility as to when and where this occurs.


Configuration
-------------

The config class associated with the SuperTask base class (and thus used as a base for all concrete SuperTasks) will include a ``quantum`` ``ConfigField`` pointing at an instance of :py:class:`QuantumConfig`, which is defined below.  This will be an optional field with a default of ``None``.

.. py:class:: QuantumConfig(lsst.pex.config.Config)

    .. py:attribute:: units

        A ``ListField`` containing ``DataUnit`` names that together indicate a unit of independent processing.
        For example, a SuperTask that processes each sensor of each visit independently could use a single-element list containing the string "ObservedSensor".

        This field defaults to ``None``, but must be set to a non-empty list before being passed to the Preflight Solver (usually in a default override when defining a concrete SuperTask).

    .. py:attribute:: whereExpression

        A string SQL expression to be included in the WHERE clause of the query that identifies the inputs and outputs of a single Quantum for this SuperTask.
        This will be combined with WHERE terms that set each :ref:`DataUnit` in ``QUANTUM_UNITS`` to a scalar value, with any additional :ref:`DataUnit` tables included via an inner join on the predefined relationships between those tables.

        Defaults to None, indicating that the predefined :ref:`DataUnit` relationships are sufficient and no additional filtering is needed.  This default should be appropriate for all one-to-one SuperTasks.

        This may include ``str.format``-style substitution strings with keys that match the names of other config fields in the parent SuperTask's config (including "."-separated fields of child configs).
        This should always be used to include the (configurable) names of of input and output :ref:`DatasetTypes <DatasetType>`, and it may also be used to allow numeric thresholds to be configured independently of the rest of the expression.

    .. py::attribute:: whereUnits

        A ``ListField`` containing the names of any *additional* :ref:`DataUnits <DataUnit>` whose fields are used by ``whereExpression``, beyond those present in ``units`` or the input and output ``DatasetTypes`` of the SuperTask (or any :ref:`DataUnits <DataUnit>` brought in as a dependency thereof).

        Defaults to an empty list, which should be appropriate for nearly all SuperTasks.


    .. py:attribute:: whereDatasetTypes

        A ``ListField`` of DatasetType names whose Datasets must already exist before processing begins, ensuring that any StorageClass tables associated with those Datasets will also exist.
        These storage class tables are then joined into the query onto which ``whereExpression`` is appended, allowing their fields to be used in the expression.
        The StorageClass tables will be aliased to the DatasetType name, allowing the same StorageClass to be included multiple times and associated with different DatasetTypes (and hence idfferent rows of the StorageClass table).

        This list may include DatasetTypes not used directly as inputs by this SuperTask, but including a DatasetType in any SuperTask's ``whereDatasetTypes`` attribute prohibits any instances of it from being created, which also means that no SuperTask in the same Pipeline may use it as an output DatasetType.

        Defaults to an empty list.

        .. note::

            This field should only be set when StorageType tables are actually used by ``expression``, as changing it indicates an algorithmic configuration change, not just a processing change.  More general prevention of the creation of a particular DatasetType should be accomplished by removing any SuperTasks that outputs it from a Pipeline.


In addition, the specialized ``DatasetField`` config class can now be generalized.
``DatasetField`` previously allowed the :ref:`DatasetType` names used by a SuperTask to be configured while holding the associated :ref:`DataUnits <DataUnit>` fixed, but now the :ref:`DataUnits <DataUnit>` can be configurable as well.
This lets us implement it as just another ``ConfigField`` with a new common config class:

.. py:class:: DatasetTypeConfig

    .. py:attribute:: name

        Name of the DatasetType (``str``).

    .. py:attribute:: units

        ``ListField`` containing the names of the :ref:`DataUnits <DataUnit>` that identify Datasets of this type.

        This list need not include dependencies (e.g. :ref:`Visit` can be included on its own, with :ref:`Camera` implied).

    .. py:method:: makeDatasetType(self)

        Return a DatasetType instance constructed with the fields of this config.


SuperTask ABC
-------------

The most prominent change to the API of SuperTask itself is the removal of ``defineQuanta``, but we include the full SuperTask API here for clarity.
This also provides an opportunity to clarify the interfaces necessary for dealing with construction-time datasets, which were incompletely handled by the previous design.

.. py:class:: SuperTask(Task)

    .. py:classmethod:: getInputFields(cls)

        Return a list of the names of all :py:class:`DatasetTypeConfig` fields whose :ref:`DatasetTypes <DatasetType>` are used as inputs by :py:meth:`runQuantum`.

        Pure abstract.

    .. py:classmethod:: getOutputFields(cls)

        Return a list of the names of all :py:class:`DatasetTypeConfig` fields whose :ref:`DatasetTypes <DatasetType>` are used as outputs by :py:meth:`runQuantum`.

        Pure abstract.

    .. py:classmethod:: getInitInputFields(cls)

        Return a list of the names of all :py:class:`DatasetTypeConfig` fields whose :ref:`DatasetTypes <DatasetType>` can be used to obtain the values of the ``inputs`` dict passed to :py:meth:`SuperTask.__init__`.

        :ref:`DatasetTypes <DatasetType>` used in initialization may not have any :ref:`DataUnits <DataUnit>`.

        Default implementation returns an empty list.

    .. py:classmethod:: getInitOutputFields(cls)

        Return a list of the names of all :py:class:`DatasetTypeConfig` fields whose :ref:`DatasetTypes <DatasetType>` are available as outputs after constructing an instance of this SuperTask (via getInitOutputs).

        :ref:`DatasetTypes <DatasetType>` produced by initialization may not have any :ref:`DataUnits <DataUnit>`.

        Default implementation returns an empty list.

    .. py:method:: __init__(self, inputs, **kwds)

        Construct an instance of the SuperTask.

        The only parameter not forwarded to the ``Task`` constructor, ``inputs``, is a ``dict`` whose keys are the same as those returned by :py:meth:`getInitInputFields`.  Values are Python objects needed to construct the SuperTask (typically schemas of catalogs produced by predecessor SuperTasks).

        All concrete SuperTasks must have the same constructor signature, but may have different elements in the ``inputs`` dictionary.

    .. py:method:: getInitOutputs(self)

        Return a dict whose keys match those of ``getInitOutputFields`` and whose values contain the objects to be saved.

        Pure abstract.

    .. py:method:: runQuantum(self, quantum, butler)

        Execute the SuperTask, using the :py:class:`DatasetRef2` instances from the given :py:class:`Quantum` and a butler to do all I/O.

        Pure abstract.

        .. note::

            We should probably make it possible to add a "translation" dict to Quantum to let it map a SuperTask's config field names to the DatasetType names they point to - otherwise every concrete SuperTask will have to do all of that dereferencing itself, which adds a lot of boilerplate.


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


Preflight Solver Algorithm
==========================
