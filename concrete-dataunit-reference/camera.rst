.. _camera_dataunits:

Camera DataUnits
================


.. _Camera:

Camera
------

Camera :ref:`DataUnit` <DataUnit>` are essentially just sources of raw data with a constant layout of PhysicalSensors and a self-constent numbering system for Visits.

Different versions of the same camera (due to e.g. changes in hardware) should still correspond to a single Camera DataUnit.

Value:
    name

Dependencies:
    None

Python API
^^^^^^^^^^

.. _sql_Camera:

SQL Representation
^^^^^^^^^^^^^^^^^^

+------------+---------+-------------+
| *Camera*                           |
+============+=========+=============+
| camera_id  | int     | PRIMARY KEY |
+------------+---------+-------------+
| name       | varchar | UNIQUE      |
+------------+---------+-------------+


.. _PhysicalFilter:

PhysicalFilter
--------------

PhysicalFilters represent the bandpass filters that can be associated with a :ref:`Visit`.

A PhysicalFilter may or may not be associated with a particular AbstractFilter.

Value:
    name

Dependencies:
    :ref:`Camera`

Python API
^^^^^^^^^^

.. _sql_PhysicalFilter:

SQL Representation
^^^^^^^^^^^^^^^^^^

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

.. _PhysicalSensor:

PhysicalSensor
--------------

PhysicalSensors represent a sensor in a :ref:`Camera`, independent of any observations.

Because some cameras identify sensors with string names and other use numbers, we provide fields for both; the name may be a stringified integer, and the number may be autoincrement.

The ``group`` field may mean different things for different :ref:`Cameras <Camera>` (such as rafts for LSST, or groups of sensors oriented the same way relative to the focal plane for HSC).

The ``purpose`` field indicates the role of the sensor (such as science, wavefront, or guiding).
Valid choices should be standardized across :ref:`Cameras <Camera>`, but are currently TBD.

Value:
    name or number

Dependencies:
    :ref:`Camera`

Python API
^^^^^^^^^^

.. _sql_PhysicalSensor:

SQL Representation
^^^^^^^^^^^^^^^^^^

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


.. _Visit:

Visit
-----

Visits correspond to observations with the full camera at a particular pointing, possibly comprised of multiple exposures (:ref:`Snaps <Snap>`).

A Visit's ``region`` field holds an approximate but inclusive representation of its position on the sky that can be compared to the ``regions`` of other DataUnits.

Value:
    number

Dependencies:
    :ref:`Camera`

Python API
^^^^^^^^^^

.. _sql_Visit:

SQL Representation
^^^^^^^^^^^^^^^^^^

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

.. _ObservedSensor:

ObservedSensor
--------------

An ObservedSensor is simply a combination of a :ref:`Visit` and a :ref:`PhysicalSensor`.

Unlike most other :ref:`DataUnit join tables <dataunit_joins>` (which are not typically :ref:`DataUnits <DataUnit>` themselves), this one is both ubuiquitous and contains additional information: a ``region`` that represents the position of the observed sensor image on the sky.

Value:
    None

Dependencies:
    :ref:`Visit` and :ref:`PhysicalSensor`

Python API
^^^^^^^^^^

.. _sql_ObservedSensor:

SQL Representation
^^^^^^^^^^^^^^^^^^

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


.. _Snap:

Snap
----

A Snap is a single-exposure subset of a :ref:`Visit`.

.. note::

    Most non-LSST :ref:`Visits <Visit>` will have only a single Snap.

Value:
    index

Dependencies:
    :ref:`Visit`

Python API
^^^^^^^^^^

.. _sql_Snap:

SQL Representation
^^^^^^^^^^^^^^^^^^

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

.. _MasterCalib:

MasterCalib
-----------

MasterCalibs are the DataUnits that label master calibration products, and are defined as a range of :ref:`Visits <Visit>` from a given :ref:`Camera`.

MasterCalibs may additionally be specialized for a particular :ref:`PhysicalFilter`, or may be appropriate for all PhysicalFilters by setting the ``physical_filter_id`` field to ``NULL``.

The MasterCalib associated with not-yet-observed :ref:`Visits <Visit>` may be indicated by setting ``visit_end`` to ``NULL``.

Value:
    visit_begin, visit_end

Dependencies:
    :ref:`Camera` and :ref:`PhysicalFilter`

Python API
^^^^^^^^^^

.. _sql_MasterCalib:

SQL Representation
^^^^^^^^^^^^^^^^^^
+--------------------+-----+----------------------------------------------------------+
| *MasterCalib*                                                                       |
+====================+=====+==========================================================+
| master_calib_id    | int | PRIMARY KEY                                              |
+--------------------+-----+----------------------------------------------------------+
| visit_begin        | int | NOT NULL                                                 |
+--------------------+-----+----------------------------------------------------------+
| visit_end          | int |                                                          |
+--------------------+-----+----------------------------------------------------------+
| camera_id          | int | NOT NULL, REFERENCES Camera (camera_id)                  |
+--------------------+-----+----------------------------------------------------------+
| physical_filter_id | int | NOT NULL, REFERENCES PhysicalFilter (physical_filter_id) |
+--------------------+-----+----------------------------------------------------------+
| UNIQUE (camera_id, physical_filter_id)                                              |
+--------------------+-----+----------------------------------------------------------+
