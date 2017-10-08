
.. _cs_calibration_dataunits:

Calibration DataUnits
=====================

.. _cs_table_MasterCalib:

+--------------------+-----+----------------------------------------------------------+
| *MasterCalib*                                                                       |
+====================+=====+==========================================================+
| master_calib_id    | int | PRIMARY KEY                                              |
+--------------------+-----+----------------------------------------------------------+
| camera_id          | int | NOT NULL, REFERENCES Camera (camera_id)                  |
+--------------------+-----+----------------------------------------------------------+
| physical_filter_id | int | NOT NULL, REFERENCES PhysicalFilter (physical_filter_id) |
+--------------------+-----+----------------------------------------------------------+
| UNIQUE (camera_id, physical_filter_id)                                              |
+--------------------+-----+----------------------------------------------------------+

:ref:`Master calibration products <cs_table_MasterCalib>` are defined over a range
of Visits from a given Camera (see :ref:`MasterCalibVisitJoin <cs_table_MasterCalibVisitJoin>`).
Calibration products may additionally be specialized for a particular
PhysicalFilter, or may be appropriate for all PhysicalFilters by setting the
``physical_filter_id`` field to ``NULL``.
