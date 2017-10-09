
.. _sql_dataset_dataunit_joins:

Dataset-DataUnit Joins
======================

The join tables in this section relate concrete :ref:`DataUnit <DataUnit>` to :ref:`Datasets <Dataset>`.
They thus hold the information necessary to relate :ref:`DatasetRefs <DatasetRef>` to :ref:`Datasets <Dataset>`.

.. todo::

    These tables all need to be updated to add ``registry_id`` and utilize the new compound :ref:`DataUnit` primary keys.


.. _cs_table_PhysicalFilterDatasetJoin:

+--------------------+-----+----------------------------------------------------------+
| *PhysicalFilterDatasetJoin*                                                         |
+====================+=====+==========================================================+
| physical_filter_id | int | NOT NULL, REFERENCES PhysicalFilter (physical_filter_id) |
+--------------------+-----+----------------------------------------------------------+
| dataset_id         | int | NOT NULL, REFERENCES Dataset (dataset_id)                |
+--------------------+-----+----------------------------------------------------------+
    
.. _cs_table_PhysicalSensorDatasetJoin:

+--------------------+-----+----------------------------------------------------------+
| *PhysicalSensorDatasetJoin*                                                         |
+====================+=====+==========================================================+
| physical_sensor_id | int | NOT NULL, REFERENCES PhysicalSensor (physical_sensor_id) |
+--------------------+-----+----------------------------------------------------------+
| dataset_id         | int | NOT NULL, REFERENCES Dataset (dataset_id)                |
+--------------------+-----+----------------------------------------------------------+

.. _cs_table_VisitDatasetJoin:

+------------+-----+------------------------------------------------------------------+
| *VisitDatasetJoin*                                                                  |
+============+=====+==================================================================+
| visit_id   | int | NOT NULL, REFERENCES Visit (visit_id)                            |
+------------+-----+------------------------------------------------------------------+
| dataset_id | int | NOT NULL, REFERENCES Dataset (dataset_id)                        |
+------------+-----+------------------------------------------------------------------+

.. _cs_table_ObservedSensorDatasetJoin:

+--------------------+-----+----------------------------------------------------------+
| *ObservedSensorDatasetJoin*                                                         |
+====================+=====+==========================================================+
| observed_sensor_id | int | NOT NULL, REFERENCES ObservedSensor (observed_sensor_id) |
+--------------------+-----+----------------------------------------------------------+
| dataset_id         | int | NOT NULL, REFERENCES Dataset (dataset_id)                |
+--------------------+-----+----------------------------------------------------------+

.. _cs_table_SnapDatasetJoin:

+------------+-----+------------------------------------------------------------------+
| *SnapDatasetJoin*                                                                   |
+============+=====+==================================================================+
| snap_id    | int | NOT NULL, REFERENCES Snap (snap_id)                              |
+------------+-----+------------------------------------------------------------------+
| dataset_id | int | NOT NULL, REFERENCES Dataset (dataset_id)                        |
+------------+-----+------------------------------------------------------------------+

.. _cs_table_AbstractFilterDatasetJoin:

+--------------------+-----+----------------------------------------------------------+
| *AbstractFilterDatasetJoin*                                                         |
+====================+=====+==========================================================+
| abstract_filter_id | int | NOT NULL, REFERENCES AbstractFilter (abstract_filter_id) |
+--------------------+-----+----------------------------------------------------------+
| dataset_id         | int | NOT NULL, REFERENCES Dataset (dataset_id)                |
+--------------------+-----+----------------------------------------------------------+

.. _cs_table_TractDatasetJoin:

+--------------------+-----+----------------------------------------------------------+
| *TractDatasetJoin*                                                                  |
+====================+=====+==========================================================+
| tract_id           | int | NOT NULL, REFERENCES Tract (tract_id)                    |
+--------------------+-----+----------------------------------------------------------+
| dataset_id         | int | NOT NULL, REFERENCES Dataset (dataset_id)                |
+--------------------+-----+----------------------------------------------------------+

.. _cs_table_PatchDatasetJoin:

+------------+-----+------------------------------------------------------------------+
| *PatchDatasetJoin*                                                                  |
+============+=====+==================================================================+
| patch_id   | int | NOT NULL, REFERENCES Patch (patch_id)                            |
+------------+-----+------------------------------------------------------------------+
| dataset_id | int | NOT NULL, REFERENCES Dataset (dataset_id)                        |
+------------+-----+------------------------------------------------------------------+

