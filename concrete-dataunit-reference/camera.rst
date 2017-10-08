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
