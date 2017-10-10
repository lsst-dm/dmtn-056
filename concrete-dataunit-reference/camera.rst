.. _camera_dataunits:

Camera DataUnits
================


.. _Camera:

Camera
------

Camera :ref:`DataUnit` <DataUnit>` are essentially just sources of raw data with a constant layout of PhysicalSensors and a self-constent numbering system for Visits.

Different versions of the same camera (due to e.g. changes in hardware) should still correspond to a single Camera :ref:`DataUnit`.
There are thus multiple ``afw.cameraGeom.Camera`` objects associated with a single Camera :ref:`DataUnit`; the most natural approach to relating them would be to store the ``afw.cameraGeom.Camera`` as a :ref:`MasterCalib` :ref:`Dataset`.

Like :ref:`SkyMap` but unlike every other :ref:`DataUnit`, :ref:`Cameras <Camera>` are represented by a polymorphic class hierarchy in Python rather than a single concrete class.

Value:
    name

Dependencies:
    None

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

        This virtual method will be called by a :ref:`Registry` when it adds a new :ref:`Camera` to populate its :ref:`PhysicalFilters table <sql_PhysicalFilter>`.

    .. py:method:: makePhysicalFilters()

        Return the full list of :py:class:`PhysicalFilter` instances associated with the Camera.

        This virtual method will be called by a :ref:`Registry` when it adds a new :ref:`Camera` to populate its :ref:`PhysicalFilters table <sql_PhysicalFilter>`.


.. _sql_Camera:

SQL Representation
^^^^^^^^^^^^^^^^^^

+------------+---------+-------------+
| *Camera*                           |
+============+=========+=============+
| name       | varchar | NOT NULL    |
+------------+---------+-------------+
| module     | varchar | NOT NULL    |
+------------+---------+-------------+

Primary Key:
    name

``module`` is a string containing a fully-qualified Python module that can be imported to ensure that ``Camera.instances[name]`` returns a :py:class:`Camera` instance.


.. _PhysicalFilter:

PhysicalFilter
--------------

PhysicalFilters represent the bandpass filters that can be associated with a :ref:`Visit`.

A PhysicalFilter may or may not be associated with a particular AbstractFilter.

Value:
    name

Dependencies:
    - :ref:`Camera`
    - :ref:`AbstractFilter` (optional)

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
| name                 | varchar | NOT NULL |
+----------------------+---------+----------+
| camera_name          | varchar | NOT NULL |
+----------------------+---------+----------+
| abstract_filter_name | varchar |          |
+----------------------+---------+----------+

Primary Key:
    (name, camera_name)

Foreign Keys:
    - (camera_name) references :ref:`Camera` (name)
    - (abstract_filter_name) references :ref:`AbstractFilter` (name)


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
    number

Dependencies:
    - :ref:`Camera`

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

+--------------------+---------+----------+
| *PhysicalSensor*   |                    |
+====================+=========+==========+
| number             | varchar | NOT NULL |
+--------------------+---------+----------+
| name               | varchar |          |
+--------------------+---------+----------+
| camera_name        | varchar | NOT NULL |
+--------------------+---------+----------+
| group              | varchar |          |
+--------------------+---------+----------+
| purpose            | varchar |          |
+--------------------+---------+----------+

Primary Key:
    (number, camera_name)

Foreign Keys:
    - (camera_name) references :ref:`Camera` (name)

.. _Visit:

Visit
-----

Visits correspond to observations with the full camera at a particular pointing, possibly comprised of multiple exposures (:ref:`Snaps <Snap>`).

A Visit's ``region`` field holds an approximate but inclusive representation of its position on the sky that can be compared to the ``regions`` of other DataUnits.

Value:
    number

Dependencies:
    - :ref:`Camera`

Many-to-Many Joins:
    - :ref:`PhysicalSensor` via :ref:`ObservedSensor`
    - :ref:`Tract` via :ref:`sql_VisitTractJoin`
    - :ref:`Patch` via :ref:`sql_VisitPatchJoin`


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

    .. py:attribute:: obs_begin

        The date and time of the beginning of the Visit.

    .. py:attribute:: obs_end

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
| number                | int      | NOT NULL |
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

Primary Key:
    (number, camera_name)

Foreign Keys:
    - (camera_name) references :ref:`Camera` (name)
    - (camera_name, physical_filter_name) references :ref:`PhysicalFilter` (camera_name, name)


.. _ObservedSensor:

ObservedSensor
--------------

An ObservedSensor is simply a combination of a :ref:`Visit` and a :ref:`PhysicalSensor`.

Unlike most other :ref:`DataUnit join tables <dataunit_joins>` (which are not typically :ref:`DataUnits <DataUnit>` themselves), this one is both ubuiquitous and contains additional information: a ``region`` that represents the position of the observed sensor image on the sky.

.. todo::

    Visits should probably have a fair amount of additional metadata.

Value:
    None

Dependencies:
    - :ref:`Visit`
    - :ref:`PhysicalSensor`

Many-to-Many Joins:
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

Primary Key:
    (visit_number, physical_sensor_number, camera_name)

Foreign Keys:
    - (camera_name) references :ref:`Camera` (name)
    - (camera_name, visit_number) references :ref:`Visit` (camera_name, number)
    - (camera_name, physical_sensor_number) references :ref:`PhysicalSensor` (camera_name, number)


.. _Snap:

Snap
----

A Snap is a single-exposure subset of a :ref:`Visit`.

Most non-LSST :ref:`Visits <Visit>` will have only a single Snap.

Value:
    index

Dependencies:
    :ref:`Visit`

Many-to-Many Joins:
    None

Python API
^^^^^^^^^^

.. py:class:: Snap

    .. py:attribute:: camera

        The :py:class:`Camera` instance associated with the ObservedSensor.

    .. py:attribute:: visit

        The :py:class:`Visit` instance associated with the ObservedSensor.

    .. py:attribute:: obs_begin

        The date and time of the beginning of the Visit.

    .. py:attribute:: obs_end

        The date and time of the end of the Visit.


.. _sql_Snap:

SQL Representation
^^^^^^^^^^^^^^^^^^

+---------------+----------+----------+
| *Snap*                              |
+===============+==========+==========+
| visit_number  | int      | NOT NULL |
+---------------+----------+----------+
| index         | int      | NOT NULL |
+---------------+----------+----------+
| camera_name   | varchar  | NOT NULL |
+---------------+----------+----------+
| obs_begin     | datetime | NOT NULL |
+---------------+----------+----------+
| obs_end       | datetime | NOT NULL |
+---------------+----------+----------+

Primary Key:
    (visit_number, index, camera_name)

Foreign Keys:
    - (camera_name) references :ref:`Camera` (name)
    - (camera_name, visit_number) references :ref:`Visit` (camera_name, number)


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
    - :ref:`Camera`
    - :ref:`PhysicalFilter` (optional)

Many-to-Many Joins:
    - :ref:`Visit` via :ref:`sql_MasterCalibVisitJoin`

Python API
^^^^^^^^^^

.. py:class:: MasterCalib

    .. py:attribute:: camera

        The :py:class:`Camera` instance associated with the MasterCalib.

    .. py:attribute:: visit_begin

        The number of the first :py:class:`Visit` instance associated with the ObservedSensor.

    .. py:attribute:: obs_begin

        The number of the last :py:class:`Visit` instance associated with the ObservedSensor, or ``-1`` for an open range.

    .. py:attribute:: obs_end

        The date and time of the end of the Visit.

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

Primary Key:
    (visit_begin, visit_end, camera_name, physical_filter_name)

Foreign Keys:
    - (camera_name) references :ref:`Camera` (name)
    - (camera_name, physical_filter_name) references :ref:`Visit` (camera_name, number)
