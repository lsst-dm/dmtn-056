
.. _dataunits:

DataUnit Reference
==================

.. _DataUnit:

DataUnit
--------

A DataUnit is a discrete abstract unit of data that can be associated with metadata and used to label :ref:`Datasets <Dataset>`.

Visit, tract, and filter are examples of *types* of DataUnits; individual visits, tracts, and filters would thus be DataUnit instances.

Each DataUnit type has both a concrete Python class (inheriting from the abstract :py:class:`DataUnit` base class) and a SQL table in the common :ref:`Registry` schema.

A DataUnit type may *depend* on another.
In SQL, this is expressed as a foreign key field in the table for the dependent DataUnit that points to the primary key field of its table for the DataUnit it depends on.

Some DataUnits represent joins between other DataUnits.
A join DataUnit *depends* on the two DataUnits it connects, but is also included automatically in any sequence, container, or machine-generated SQL query in which its dependencies are both present.

Every DataUnit type that is not a join has a "value".
This is a POD (usually a string or integer, but sometimes a tuple of these) that is both its default human-readable representation *and* a "semi-unique" identifier for the DataUnit: when combined with the "values" of the DataUnits it depends on, the full set of DataUnits is uniquely identified.

DataUnit tables in SQL typically have compound primary keys that include the primary keys of the DataUnits they depend on.  These primary keys are also meaningful in Python; they can be accessed as tuples via the :py:attr:`DataUnit.pkey` attribute and are frequently used in dictionaries containing DataUnits.

The :py:class:`DataUnitTypeSet` class provides methods that enforce and utilize these rules, providing a centralized implementation to which all other objects that operate on groups of DataUnits can delegate.

The :py:class:`DataUnitMap` class provides Python access to the more complex relationships between DataUnits, including many-to-many joins.

Transition
^^^^^^^^^^

The string keys of data ID dictionaries passed to the v14 Butler are similar to DataUnit type names, and the values of data ID dictionaries are similar to DataUnit values.

A dictionary that maps DataUnit type names to DataUnit values is thus *very* similar to a v14 data ID dictionary, but most layers of the new design instead use a tuple of DataUnits, a strongly-typed analog that provides a bit more functionality and access to structured metadata.

Python API
^^^^^^^^^^

.. py:class:: DataUnit

    An abstract base class whose subclasses represent concrete :ref:`DataUnits <DataUnit>`.

    .. py:attribute:: pkey

        Read-only pure-virtual instance attribute (must be implemented by subclasses).

        A tuple of POD values that uniquely identify the DataUnit, corresponding to the values in the SQL primary key.

        *Primary keys in Python are always tuples, even when only a single value is needed to identify the DataUnit type.*

    .. py:attribute:: value

        Read-only pure-virtual instance attribute (must be implemented by subclasses).

        An integer or string that identifies the :ref:`DataUnit` when combined with any "foreign key" connections to other :ref:`DataUnits <DataUnit>`.
        For example, a Visit's number is its value, because it uniquely labels a Visit as long as its Camera (its only foreign key :ref:`DataUnit`) is also specified.


.. py:class:: DataUnitTypeSet

    An ordered tuple of unique DataUnit subclasses.

    Unlike a regular Python tuple or set, a DataUnitTypeSet's elements are sorted (the actual sort order is TBD, but it is deterministic).
    In addition, the inclusion of certain DataUnit types can automatically lead to to the inclusion of others.  This can happen because one DataUnit depends on another (most depend on either Camera or SkyMap, for instance), or because a DataUnit (such as ObservedSensor) represents a join between others (such as Visit and PhysicalSensor).
    For example, if any of the following combinations of DataUnit types are used to initialize a DataUnitTypeSet, its elements will be ``[Camera, ObservedSensor, PhysicalSensor, Visit]``:

    - ``[Visit, PhysicalSensor]``
    - ``[ObservedSensor]``
    - ``[Visit, ObservedSensor, Camera]``
    - ``[Visit, PhysicalSensor, ObservedSensor]``

    .. py:method:: __init__(elements)

        Initialize the DataUnitTypeSet with a reordered and augmented version of the given DataUnit types as described above.

    .. py:method:: __iter__()

        Iterate over the DataUnit types in the set.

    .. py:method:: __len__()

        Return the number of DataUnit types in the set.

    .. py:method:: __eq__(other)

        Compare two DataUnitTypeSets for equality.

        Also supports comparisons with other sequences by converting them to DataUnitTypeSets.

    .. py:method:: __ne__(other)

        Compare two DataUnitTypeSets for inequality.

        Also supports comparisons with other sequences by converting them to DataUnitTypeSets.

    .. py:method:: __contains__(k)

        Return True if the DataUnitTypeSet contains either the given DataUnit type or DataUnit type name.

    .. py:method:: __getitem__(name)

        Return the DataUnit type with the given name.

    .. py:method:: pack(values)

        Compute an ``bytes`` string that uniquely identifies the given combination of :ref:`DataUnit` values.

        :param dict values: A dictionary that maps :ref:`DataUnit` type names to either the "values" of those units or actual :ref:`DataUnit` instances.

        :returns: a ``bytes`` object that labels the given combination of units.

        This method must be used to populate the ``unit_pack`` field in the :ref:`sql_Dataset` table.

    .. py:method:: expand(findfunc, values)

        Construct a dictionary of DataUnit instances from a dictionary of DataUnit "values".

        :param findfunc: a callable with the same signature and behavior :py:meth:`Registry.findDataUnit` or :py:meth:`DataUnitMap.findDataUnit`.

        This can (and generally should) be used by concrete :ref:`Registries <Registry>` to implement :py:meth:`Registry.expand`.


.. py:class:: DataUnitMap

    An object that holds a collection of related DataUnits.

    .. py:attribute:: types

        A :py:class:`DataUnitTypeSet` containing exactly the DataUnit types present in the map.

    .. py:method:: extract(types)

        Iterate over tuples of DataUnit instances.

        :param DataUnitTypeSet types: the DataUnit types to iterate over.  Must be a subset of :py:attr:`self.types <DataUnitMap.types>`.

        :returns: a sequence of tuples of DataUnits whose types correspond to the ``types`` argument (in the same order).

    .. py:method:: group(types)

        Group the DataUnitMap according to a subset of its DataUnit types.

        :param DataUnitTypeSet types: the DataUnit types to group by.  Must be a subset of :py:attr:`self.types <DataUnitMap.types>`.

        :returns: a sequence of tuples of ``(units, submap)``, where ``types`` is a tuple of DataUnits whose types correspond to the ``types`` argument (in the same order), and ``submap`` is a DataUnitMap containing only the DataUnits and DatasetRefs related to the ones in ``units``.  The types in ``submap`` are the same as those in ``self``.

        For example, the following code performs a nested iteration over the :ref:`Tracts <Tract>` and :ref:`Patches <Patch>` in a DataUnitMap

        .. code:: python

            assert map.types == (SkyMap, Tract, Patch)

            for (skymap, tract), submap in map.group((SkyMap, Tract)):
                assert submap.types == (SkyMap, Tract, Patch)
                for patch in submap.extract(Patch):
                    ...

    .. py:method:: findDataUnit(cls, pkey)

        Return a :ref:`DataUnit` given the values of its primary key.

        :param type cls: a class that inherits from :py:class:`DataUnit`.

        :param tuple pkey: a tuple of primary key values that uniquely identify the :ref:`DataUnit`; see :py:attr:`DataUnit.pkey`.

        :returns: a :py:class:`DataUnit` instance of type ``cls``, or ``None`` if no matching unit is found.

        See also :py:meth:`Registry.findDataUnit`.


SQL Representation
^^^^^^^^^^^^^^^^^^

There is one table for each :ref:`DataUnit` type, and a :ref:`DataUnit` instance is a row in one of those tables.
Being abstract, there is no single table associated with :ref:`DataUnits <DataUnit>` in general.


.. _AbstractFilter:

AbstractFilter
--------------

AbstractFilters are used to label :ref:`Datasets <Dataset>` that aggregate data from multiple :ref:`Visits <Visit>` (and possibly multiple :ref:`Cameras <Camera>`.

Having two different :ref:`DataUnits <DataUnit>` for filters is necessary to make it possible to combine data from :ref:`Visits <Visit>` taken with different :ref:`PhysicalFilters <PhysicalFilter>`.

Value:
    abstract_filter_name

Dependencies:
    None

Primary Key:
    abstract_filter_name

Many-to-Many Joins:
    None

Python API
^^^^^^^^^^

.. py:class:: AbstractFilter

    .. py:attribute:: name

        The name of the filter.

.. _sql_AbstractFilter:

SQL Representation
^^^^^^^^^^^^^^^^^^

+----------------------------+---------+-------------+
| *AbstractFilter*                                   |
+============================+=========+=============+
| abstract_filter_namename   | varchar | NOT NULL    |
+----------------------------+---------+-------------+


.. _Camera:

Camera
------

Camera :ref:`DataUnits <DataUnit>` are essentially just sources of raw data with a constant layout of :ref:`PhysicalSensors <PhysicalSensor>` and a self-constent numbering system for :ref:`Visits <Visit>`.

Different versions of the same camera (due to e.g. changes in hardware) should still correspond to a single Camera :ref:`DataUnit`.
There are thus multiple ``afw.cameraGeom.Camera`` objects associated with a single Camera :ref:`DataUnit`; the most natural approach to relating them would be to store the ``afw.cameraGeom.Camera`` as a :ref:`MasterCalib` :ref:`Dataset`.

Like :ref:`SkyMap` but unlike every other :ref:`DataUnit`, :ref:`Cameras <Camera>` are represented by a polymorphic class hierarchy in Python rather than a single concrete class.

Value:
    camera_name

Dependencies:
    None

Primary Key:
    camera_name

Many-to-Many Joins:
    None

Transition
^^^^^^^^^^
Camera subclasses take over many of the roles played by ``obs_`` package ``Mapper`` subclasses in the v14 Butler (with :ref:`Path` creation an important and intentional exception).

Python API
^^^^^^^^^^

.. py:class:: Camera

    An abstract base class whose subclasses are generally singletons.

    .. py:attribute:: instances

        Concrete class attribute: provided by the base class.

        A dictionary holding all :py:class:`Camera` instances,
        keyed by their :py:attr:`name` attributes.
        Subclasses are responsible for adding an instance to this dictionary at module-import time.

    .. py:attribute:: name

        Virtual instance attribute: must be implemented by base classes.

        A string name for the Camera that can be used as its primary key in SQL.

    .. py:method:: makePhysicalSensors()

        Return the full list of :py:class:`PhysicalSensor` instances associated with the Camera.

        This virtual method will be called by a :ref:`Registry` when it adds a new :ref:`Camera` to populate its :ref:`PhysicalSensors table <sql_PhysicalSensor>`.

    .. py:method:: makePhysicalFilters()

        Return the full list of :py:class:`PhysicalFilter` instances associated with the Camera.

        This virtual method will be called by a :ref:`Registry` when it adds a new :ref:`Camera` to populate its :ref:`PhysicalFilters table <sql_PhysicalFilter>`.


.. _sql_Camera:

SQL Representation
^^^^^^^^^^^^^^^^^^

+-------------+---------+-------------+
| *Camera*                            |
+=============+=========+=============+
| camera_name | varchar | NOT NULL    |
+-------------+---------+-------------+
| module      | varchar | NOT NULL    |
+-------------+---------+-------------+

``module`` is a string containing a fully-qualified Python module that can be imported to ensure that ``Camera.instances[name]`` returns a :py:class:`Camera` instance.


.. _PhysicalFilter:

PhysicalFilter
--------------

PhysicalFilters represent the bandpass filters that can be associated with a :ref:`Visit`.

A PhysicalFilter may or may not be associated with a particular AbstractFilter.

Value:
    physical_filter_name

Dependencies:
    - (camera_name) -> :ref:`Camera` (camera_name)
    - (abstract_filter_name) -> :ref:`AbstractFilter` (abstract_filter_name) [optional]

Primary Key:
    camera_name, physical_filter_name

Many-to-Many Joins:
    None

Python API
^^^^^^^^^^

.. py:class:: PhysicalFilter

    .. py:attribute:: camera

        The :py:class:`Camera` instance associated with the filter.

    .. py:attribute:: name

        The name of the filter.
        Only guaranteed to be unique across PhysicalFilters associated with the same :ref:`Camera`.

    .. py:attribute:: abstract

        The associated :py:class:`AbstractFilter`, or None.


.. _sql_PhysicalFilter:

SQL Representation
^^^^^^^^^^^^^^^^^^

+----------------------+---------+----------+
| *PhysicalFilter*                          |
+======================+=========+==========+
| physical_filter_name | varchar | NOT NULL |
+----------------------+---------+----------+
| camera_name          | varchar | NOT NULL |
+----------------------+---------+----------+
| abstract_filter_name | varchar |          |
+----------------------+---------+----------+


.. _PhysicalSensor:

PhysicalSensor
--------------

PhysicalSensors represent a sensor in a :ref:`Camera`, independent of any observations.

Because some cameras identify sensors with string names and other use numbers, we provide fields for both; the name may be a stringified integer, and the number may be autoincrement.
Only the number is used as part of the primary key.

The ``group`` field may mean different things for different :ref:`Cameras <Camera>` (such as rafts for LSST, or groups of sensors oriented the same way relative to the focal plane for HSC).

The ``purpose`` field indicates the role of the sensor (such as science, wavefront, or guiding).
Valid choices should be standardized across :ref:`Cameras <Camera>`, but are currently TBD.

Value:
    physical_sensor_number

Dependencies:
    - (camera_name) -> :ref:`Camera` (camera_name)

Primary Key:
    (number, camera_name)

Many-to-Many Joins:
    - :ref:`Visit` via :ref:`ObservedSensor`

Python API
^^^^^^^^^^

.. py:class:: PhysicalSensor

    .. py:attribute:: camera

        The :py:class:`Camera` instance associated with the filter.

    .. py:attribute:: number

        A number that identifies the sensor.
        Only guaranteed to be unique across PhysicalSensors associated with the same :ref:`Camera`.

    .. py:attribute:: name

        The name of the sensor.
        Only guaranteed to be unique across PhysicalSensors associated with the same :ref:`Camera`.

    .. py:attribute:: group

        A Camera-specific group the sensor belongs to.

    .. py:attribute:: purpose

        A Camera-generic role for the sensor.


.. _sql_PhysicalSensor:

SQL Representation
^^^^^^^^^^^^^^^^^^
+--------------------------+---------+----------+
| *PhysicalSensor*         |                    |
+==========================+=========+==========+
| physical_sensor_number   | varchar | NOT NULL |
+--------------------------+---------+----------+
| name                     | varchar |          |
+--------------------------+---------+----------+
| camera_name              | varchar | NOT NULL |
+--------------------------+---------+----------+
| group                    | varchar |          |
+--------------------------+---------+----------+
| purpose                  | varchar |          |
+--------------------------+---------+----------+

.. _Visit:

Visit
-----

Visits correspond to observations with the full camera at a particular pointing, possibly comprised of multiple exposures (:ref:`Snaps <Snap>`).

A Visit's ``region`` field holds an approximate but inclusive representation of its position on the sky that can be compared to the ``regions`` of other DataUnits.

Value:
    visit_number

Dependencies:
    - (camera_name) -> :ref:`Camera` (camera_name)
    - (physical_filter_name) -> ref:`PhysicalFilter` (physical_filter_name)

Primary Key:
    (visit_number, camera_name)

Many-to-Many Joins:
    - :ref:`PhysicalSensor` via :ref:`ObservedSensor`
    - :ref:`Tract` via :ref:`sql_VisitTractJoin`
    - :ref:`Patch` via :ref:`sql_VisitPatchJoin`

.. todo::

    Visit will need to have many more fields to hold metadata (in general, we want to include anything we might want to query on when selecting Datasets).
    We should consider adding everything in ``afw.image.VisitInfo``.
    That may be true of some other concrete DataUnits as well.


Python API
^^^^^^^^^^

.. py:class:: Visit

    .. py:attribute:: camera

        The :py:class:`Camera` instance associated with the Visit.

    .. py:attribute:: number

        A number that identifies the Visit.
        Only guaranteed to be unique across Visits associated with the same :ref:`Camera`.

    .. py:attribute:: filter

        The :py:class:`PhysicalFilter` the Visit was observed with.

    .. py:attribute:: obsBegin

        The date and time of the beginning of the Visit.

    .. py:attribute:: obsEnd

        The date and time of the end of the Visit.

    .. py:attribute:: region

        An object (type TBD) that describes the spatial extent of the Visit on the sky.

    .. py:attribute:: sensors

        A sequence of :py:class:`ObservedSensor` instances associated with this Visit.


.. _sql_Visit:

SQL Representation
^^^^^^^^^^^^^^^^^^
+-----------------------+----------+----------+
| *Visit*                          |          |
+=======================+==========+==========+
| visit_number          | int      | NOT NULL |
+-----------------------+----------+----------+
| camera_name           | varchar  | NOT NULL |
+-----------------------+----------+----------+
| physical_filter_name  | varchar  | NOT NULL |
+-----------------------+----------+----------+
| obs_begin             | datetime |          |
+-----------------------+----------+----------+
| obs_end               | datetime |          |
+-----------------------+----------+----------+
| region                | blob     |          |
+-----------------------+----------+----------+


.. _ObservedSensor:

ObservedSensor
--------------

An ObservedSensor is a join between a :ref:`Visit` and a :ref:`PhysicalSensor`.

Unlike most other :ref:`DataUnit join tables <dataunit_joins>` (which are not typically :ref:`DataUnits <DataUnit>` themselves), this one is both ubuiquitous and contains additional information: a ``region`` that represents the position of the observed sensor image on the sky.
We may also add additional observational metadata in the future.

Value:
    None

Dependencies:
    - (camera_name) -> :ref:`Camera` (camera_name)
    - (visit_number, camera_name) -> :ref:`Visit` (visit_number, camera_name)
    - (physical_sensor_number, camera_name) -> :ref:`PhysicalSensor` (number, camera_name)

Primary Key:
    (visit_number, physical_sensor_number, camera_name)

Many-to-Many Joins:
    - :ref:`MasterCalib` via :ref:`sql_MasterCalibVisitJoin`
    - :ref:`Tract` via :ref:`sql_SensorTractJoin`
    - :ref:`Patch` via :ref:`sql_SensorPatchJoin`

Python API
^^^^^^^^^^

.. py:class:: ObservedSensor

    .. py:attribute:: camera

        The :py:class:`Camera` instance associated with the ObservedSensor.

    .. py:attribute:: visit

        The :py:class:`Visit` instance associated with the ObservedSensor.

    .. py:attribute:: physical

        The :py:class:`PhysicalFilter` instance associated with the ObservedSensor.

    .. py:attribute:: region

        An object (type TBD) that describes the spatial extent of the ObservedSensor on the sky.


.. _sql_ObservedSensor:

SQL Representation
^^^^^^^^^^^^^^^^^^
+------------------------+---------+----------+
| *ObservedSensor*                            |
+========================+=========+==========+
| visit_number           | int     | NOT NULL |
+------------------------+---------+----------+
| physical_sensor_number | int     | NOT NULL |
+------------------------+---------+----------+
| camera_name            | varchar | NOT NULL |
+------------------------+---------+----------+
| region                 | blob    |          |
+------------------------+---------+----------+


.. _Snap:

Snap
----

A Snap is a single-exposure subset of a :ref:`Visit`.

Most non-LSST :ref:`Visits <Visit>` will have only a single Snap.

Value:
    snap_index

Dependencies:
    - (camera_name) -> :ref:`Camera` (camera_name)
    - (visit_number, camera_name) -> :ref:`Visit` (visit_number, camera_name)

Primary Key:
    (snap_index, visit_number, camera_name)

Many-to-Many Joins:
    None

Python API
^^^^^^^^^^

.. py:class:: Snap

    .. py:attribute:: camera

        The :py:class:`Camera` instance associated with the ObservedSensor.

    .. py:attribute:: visit

        The :py:class:`Visit` instance associated with the ObservedSensor.

    .. py:attribute:: obsBegin

        The date and time of the beginning of the Visit.

    .. py:attribute:: obsEnd

        The date and time of the end of the Visit.


.. _sql_Snap:

SQL Representation
^^^^^^^^^^^^^^^^^^
+---------------+----------+----------+
| *Snap*                              |
+===============+==========+==========+
| visit_number  | int      | NOT NULL |
+---------------+----------+----------+
| snap_index    | int      | NOT NULL |
+---------------+----------+----------+
| camera_name   | varchar  | NOT NULL |
+---------------+----------+----------+
| obs_begin     | datetime | NOT NULL |
+---------------+----------+----------+
| obs_end       | datetime | NOT NULL |
+---------------+----------+----------+


.. _MasterCalib:

MasterCalib
-----------

MasterCalibs are the DataUnits that label master calibration products, and are defined as a range of :ref:`Visits <Visit>` from a given :ref:`Camera`.

MasterCalibs may additionally be specialized for a particular :ref:`PhysicalFilter`, or may be appropriate for all PhysicalFilters by setting the ``physical_filter_name`` field to an empty string ``""``, though we map this to ``None`` in Python.

The MasterCalib associated with not-yet-observed :ref:`Visits <Visit>` may be indicated by setting ``visit_end`` to ``-1``.  This is also mapped to ``None`` in Python.

We probably can't use ``NULL`` for ``physical_filter_name`` and ``visit_end`` because these are part of the compound primary key.

.. note::

    The fact that all of the fields in this table are part of the compound primary key is a little worrying.
    If we could come up with some other globally-meaningful label for a set of master calibrations, we could instead make the join-to-visit table authoritative (instead of an easily-calculated view).
    But that would require some ugly two-way synchronizations whenever either MasterCalib or Visit DataUnits are added.

Value:
    visit_begin, visit_end

Dependencies:
    - (camera_name) -> :ref:`Camera` (camera_name)
    - (physical_filter_name, camera_name) -> :ref:`PhysicalFilter` (physical_filter_name, camera_name) [optional]

Primary Key:
    (visit_begin, visit_end, physical_filter_name, camera_name)

Many-to-Many Joins:
    - :ref:`Visit` via :ref:`sql_MasterCalibVisitJoin`

Python API
^^^^^^^^^^

.. py:class:: MasterCalib

    .. py:attribute:: camera

        The :py:class:`Camera` instance associated with the MasterCalib.

    .. py:attribute:: visitBegin

        The number of the first :py:class:`Visit` instance associated with the ObservedSensor.

    .. py:attribute:: visitEnd

        The number of the last :py:class:`Visit` instance associated with the ObservedSensor, or ``-1`` for an open range.

    .. py:attribute:: filter

        The :py:class:`PhysicalFilter` associated with the MasterCalib, or None.


.. _sql_MasterCalib:

SQL Representation
^^^^^^^^^^^^^^^^^^
+-----------------------+---------+----------+
| *MasterCalib*                              |
+=======================+=========+==========+
| visit_begin           | int     | NOT NULL |
+-----------------------+---------+----------+
| visit_end             | int     | NOT NULL |
+-----------------------+---------+----------+
| physical_filter_name  | varchar | NOT NULL |
+-----------------------+---------+----------+
| camera_name           | varchar | NOT NULL |
+-----------------------+---------+----------+


.. _SkyMap:

SkyMap
------

Each SkyMap entry represents a different way to subdivide the sky into tracts and patches, including any parameters involved in those definitions.

SkyMaps in Python are part of a polymorphic hierarchy, but unlike Cameras, their instances are not singletons, so we can't just store them in a global dictionary in the software stack.
Instead, we serialize SkyMap instances directly into the :ref:`Registry` as blobs.

Value:
    skymap_name

Dependencies:
    None

Primary Key:
    skymap_name

Many-to-Many Joins:
    None

Transition
^^^^^^^^^^

Ultimately this SkyMap hierarchy should entirely replace those in the v14 ``lsst.skymap`` package, and we'll store the SkyMap information directly in the Registry database rather than a separate pickle file.
There's no need for two parallel class hierarchies to represent the same concepts.

Python API
^^^^^^^^^^

.. py:class:: SkyMap

    .. py:attribute:: name

        A unique, human-readable name for the SkyMap that can be used as its primary key in SQL.

    .. py:method:: makeTracts()

        Return the full list of :py:class:`Tract` instances associated with the Skymap.

        This virtual method will be called by a :ref:`Registry` when it adds a new :ref:`SkyMap` to populate its :ref:`Tract <sql_Tract>` and :ref:`Patch <sql_Patch>` tables.

    .. py:method:: serialize()

        Write the SkyMap to a blob.

    .. py:classmethod:: deserialize(name, blob)

        Reconstruct a SkyMap instance from a blob.

    .. todo::

        * Add other methods from ``lsst.skymap.BaseSkyMap``, including iteration over Tracts.
          That may suggest removing :py:meth:`makeTracts` if it becomes redundant, or adding arguments to :py:meth:`deserialize` to provide Tracts and Patches from their tables instead of the blob.

        * What is the connection between ``serialize()``, ``deserialize()`` and ``__reduce__``?
          Can we just use pickle?


.. _sql_SkyMap:

SQL Representation
^^^^^^^^^^^^^^^^^^
+----------------+---------+--------------+
| *SkyMap*                                |
+================+=========+==============+
| skymap_name    | varchar | NOT NULL     |
+----------------+---------+--------------+
| module         | varchar | NOT NULL     |
+----------------+---------+--------------+
| serialized     | blob    | NOT NULL     |
+----------------+---------+--------------+


.. _Tract:

Tract
-----

A Tract is a contiguous, simple area on the sky with a 2-d Euclidian coordinate system related to spherical coordinates by a single map projection.

.. todo::

    If the parameters of the sky projection and/or the Tract's various bounding boxes can be standardized across all SkyMap implementations, it may be useful to include them in the table as well.

Value:
    tract_number

Dependencies:
    - (skymap_name) -> :ref:`SkyMap` (skymap_name)

Primary Key:
    (tract_number, skymap_name)

Many-to-Many Joins:
    - :ref:`ObservedSensor` via :ref:`sql_SensorTractJoin`
    - :ref:`Visit` via :ref:`sql_VisitTractJoin`

Transition
^^^^^^^^^^

Should eventually fully replace v14's ``lsst.skymap.TractInfo``.

Python API
^^^^^^^^^^

.. py:class:: Tract

    .. py:attribute:: skymap

        The associated :py:class:`SkyMap` instance.

    .. py:attribute:: number

        An integer that identifies this Tract within its :ref:`SkyMap`.

    .. py:attribute:: region

        An object (type TBD) that represents the Tract's extent on the sky.

    .. todo::

        Add other methods from ``lsst.skymap.TractInfo``.

.. _sql_Tract:

SQL Representation
^^^^^^^^^^^^^^^^^^
+--------------+---------+----------+
| *Tract*                           |
+==============+=========+==========+
| tract_number | int     | NOT NULL |
+--------------+---------+----------+
| skymap_name  | varchar | NOT NULL |
+--------------+---------+----------+
| region       | blob    |          |
+--------------+---------+----------+


.. _Patch:

Patch
-----

:ref:`Tracts <Tract>` are subdivided into Patches, which share the :ref:`Tract` coordinate system and define similarly-sized regions that overlap by a configurable amount.

.. todo::

    As with Tracts, we may want to include fields to describe Patch boundaries in this table in the future.

Value:
    patch_index

Dependencies:
    - (skymap_name) -> :ref:`SkyMap` (skymap_name)
    - (tract_number, skymap_name) -> :ref:`Tract` (tract_number, skymap_name)

Primary Key:
    (patch_index, tract_number, skymap_name)

Many-to-Many Joins:
    - :ref:`ObservedSensor` via :ref:`sql_SensorPatchJoin`
    - :ref:`Visit` via :ref:`sql_VisitPatchJoin`

Transition
^^^^^^^^^^

Should eventually fully replace v14's ``lsst.skymap.PatchInfo``.

Python API
^^^^^^^^^^

.. py:class:: Tract

    .. py:attribute:: skymap

        The associated :py:class:`SkyMap` instance.

    .. py:attribute:: tract

        The associated :py:class:`Tract` instance.

    .. py:attribute:: index

        An integer that identifies this Patch within its :ref:`Tract`.

    .. py:attribute:: region

        An object (type TBD) that represents the Patch's extent on the sky.

    .. todo::

        Add other methods from ``lsst.skymap.PatchInfo``.

.. _sql_Patch:

SQL Representation
^^^^^^^^^^^^^^^^^^
+--------------+---------+----------+
| *Patch*                           |
+==============+=========+==========+
| patch_index  | int     | NOT NULL |
+--------------+---------+----------+
| tract_number | int     | NOT NULL |
+--------------+---------+----------+
| skymap_name  | varchar | NOT NULL |
+--------------+---------+----------+
| region       | blob    |          |
+--------------+---------+----------+
