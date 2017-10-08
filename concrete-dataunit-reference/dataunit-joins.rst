
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
