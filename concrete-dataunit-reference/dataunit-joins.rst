
.. _dataunit_joins:

DataUnit Joins
==============

The spatial join tables are calculated, and may be implemented as views if those calculations can be done within the database efficiently.

Whether the :ref:`MasterCalibVisitJoin <sql_MasterCalibVisitJoin>` table is calculated is TBD; it could be considered the source of truth (overriding the ranges in the :ref:`MasterCalib table <sql_MasterCalib>`).

.. _sql_MasterCalibVisitJoin:

+-----------------+-----+----------------------------------------------------+
| *MasterCalibVisitJoin*                                                     |
+=================+=====+====================================================+
| master_calib_id | int | NOT NULL, REFERENCES MasterCalib (master_calib_id) |
+-----------------+-----+----------------------------------------------------+
| visit_id        | int | REFERENCES Visit (visit_id)                        |
+-----------------+-----+----------------------------------------------------+

.. _sql_SensorTractJoin:

+--------------------+-----+----------------------------------------------------------+
| *SensorTractJoin*                                                                   |
+====================+=====+==========================================================+
| observed_sensor_id | int | NOT NULL, REFERENCES ObservedSensor (observed_sensor_id) |
+--------------------+-----+----------------------------------------------------------+
| tract_id           | int | NOT NULL, REFERENCES Tract (tract_id)                    |
+--------------------+-----+----------------------------------------------------------+
| CONSTRAINT UNIQUE (observed_sensor_id, tract_id)                                    |
+--------------------+-----+----------------------------------------------------------+

.. _sql_SensorPatchJoin:

+--------------------+-----+-----------------------------------------------+
| *SensorPatchJoin*                                                        |
+====================+=====+===============================================+
| observed_sensor_id | int | NOT NULL, REFERENCES ObservedSensor (unit_id) |
+--------------------+-----+-----------------------------------------------+
| patch_id           | int | NOT NULL, REFERENCES Patch (unit_id)          |
+--------------------+-----+-----------------------------------------------+
| CONSTRAINT UNIQUE (observed_sensor_id, patch_id)                         |
+--------------------+-----+-----------------------------------------------+

.. _sql_VisitTractJoin:

+----------+-----+---------------------------------------+
| *VisitTractJoin*                                       |
+==========+=====+=======================================+
| visit_id | int | NOT NULL, REFERENCES Visit (visit_id) |
+----------+-----+---------------------------------------+
| tract_id | int | NOT NULL, REFERENCES Tract (tract_id) |
+----------+-----+---------------------------------------+
| CONSTRAINT UNIQUE (visit_id, tract_id)                 |
+----------+-----+---------------------------------------+

.. _sql_VisitPatchJoin:

+----------+-----+---------------------------------------+
| *VisitPatchJoin*                                       |
+==========+=====+=======================================+
| visit_id | int | NOT NULL, REFERENCES Visit (visit_id) |
+----------+-----+---------------------------------------+
| patch_id | int | NOT NULL, REFERENCES Patch (patch_id) |
+----------+-----+---------------------------------------+
| CONSTRAINT UNIQUE (visit_id, patch_id)                 |
+----------+-----+---------------------------------------+
