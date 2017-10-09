
.. _dataunit_joins:

DataUnit Joins
==============

The tables (which of course may be views) in this section define many-to-many joins between :ref:`DataUnits <DataUnit>`.
Each consists of only the (compound) primary key fields of the tables being joined.

These join tables have no direct representation in Python, though the connections they define appear in a :py:class:`DataGraph`.


Calibration-Observation Joins
-----------------------------

.. _sql_MasterCalibVisitJoin:

MasterCalibVisitJoin
^^^^^^^^^^^^^^^^^^^^
Fields:
    +-------------------------+---------+----------+
    | visit_begin             | int     | NOT NULL |
    +-------------------------+---------+----------+
    | visit_end               | int     | NOT NULL |
    +-------------------------+---------+----------+
    | physical_filter_name    | varchar | NOT NULL |
    +-------------------------+---------+----------+
    | visit_number            | varchar | NOT NULL |
    +-------------------------+---------+----------+
    | camera_name             | varchar | NOT NULL |
    +-------------------------+---------+----------+
Foreign Keys:
    - (visit_begin, visit_end, physical_filter_name, camera_name) references :ref:`MasterCalib` (visit_begin, visit_end, physical_filter_name, camera_name)
    - (visit_number, camera_name) references :ref:`Visit` (number, camera_name)

.. note::

    The ``physical_filter_name`` field here may be an empty string, which would mean it would not be the same as the ``physical_filter_name`` field in :ref:`Visit`.
    This is because ``physical_filter_name`` is part of :ref:`MasterCalib's <MasterCalib>` primary key but not :ref:`Visit's <Visit>`.

Whether the :ref:`MasterCalibVisitJoin <sql_MasterCalibVisitJoin>` table is calculated is TBD; it could be considered the source of truth (overriding the ranges in the :ref:`MasterCalib table <sql_MasterCalib>`).

If this table is calculated, it can be defined with the following view:

.. code:: sql

    CREATE VIEW MasterCalibVisitJoin AS
    SELECT
        MasterCalib.visit_begin AS visit_begin,
        MasterCalib.visit_end AS visit_end,
        MasterCalib.physical_filter_name AS physical_filter_name,
        Visit.number AS visit_number,
        Visit.camera_name AS camera_name
    FROM
        Visit INNER JOIN MasterCalib ON (
            Visit.camera_name == MasterCalib.camera_name
            AND
            Visit.number >= MasterCalib.visit_begin
            AND (
                Visit.number < MasterCalib.visit_end
                OR
                MasterCalib.visit_end < 0
            ) AND (
                Visit.physical_filter_name == MasterCalib.physical_filter_name
                OR
                MasterCalib.physical_filter_name == ''
            )
        );

Spatial Joins
-------------

The spatial join tables below are calculated from the ``region`` fields in the tables they join, and may all be implemented as views if those calculations can be done within the database efficiently.
All but :ref:`SensorPatchJoin <sql_SensorPatchJoin>` may be implemented as views against it, but it may be more efficient to materialize all of them.

.. _sql_SensorPatchJoin:

SensorPatchJoin
^^^^^^^^^^^^^^^
Fields:
    +------------------------+---------+----------+
    | visit_number           | int     | NOT NULL |
    +------------------------+---------+----------+
    | physical_sensor_number | int     | NOT NULL |
    +------------------------+---------+----------+
    | camera_name            | varchar | NOT NULL |
    +------------------------+---------+----------+
    | tract_number           | int     | NOT NULL |
    +------------------------+---------+----------+
    | patch_index            | int     | NOT NULL |
    +------------------------+---------+----------+
    | skymap_name            | varchar | NOT NULL |
    +------------------------+---------+----------+

Foreign Keys:
    - (visit_number, physical_sensor_number, camera_name) references :ref:`ObservedSensor` (visit_number, physical_sensor_number, camera_name)
    - (tract_number, patch_index, skymap_name) references :ref:`Patch` (tract_number, index, skymap_name)


.. _sql_SensorTractJoin:

SensorTractJoin
^^^^^^^^^^^^^^^
Fields:
    +------------------------+---------+----------+
    | visit_number           | int     | NOT NULL |
    +------------------------+---------+----------+
    | physical_sensor_number | int     | NOT NULL |
    +------------------------+---------+----------+
    | camera_name            | varchar | NOT NULL |
    +------------------------+---------+----------+
    | tract_number           | int     | NOT NULL |
    +------------------------+---------+----------+
    | skymap_name            | varchar | NOT NULL |
    +------------------------+---------+----------+

Foreign Keys:
    - (visit_number, physical_sensor_number, camera_name) references :ref:`ObservedSensor` (visit_number, physical_sensor_number, camera_name)
    - (tract_number, skymap_name) references :ref:`Tract` (tract_number, skymap_name)

May be implemented as:

.. code:: sql

    CREATE VIEW SensorTractJoin AS
    SELECT DISTINCT
        visit_number,
        physical_sensor_number,
        camera_name,
        tract_number,
        skymap_name
    FROM
        SensorPatchJoin;


.. _sql_VisitPatchJoin:

VisitPatchJoin
^^^^^^^^^^^^^^
Fields:
    +------------------------+---------+----------+
    | visit_number           | int     | NOT NULL |
    +------------------------+---------+----------+
    | camera_name            | varchar | NOT NULL |
    +------------------------+---------+----------+
    | tract_number           | int     | NOT NULL |
    +------------------------+---------+----------+
    | patch_index            | int     | NOT NULL |
    +------------------------+---------+----------+
    | skymap_name            | varchar | NOT NULL |
    +------------------------+---------+----------+

Foreign Keys:
    - (visit_number, camera_name) references :ref:`Visit` (visit_number, camera_name)
    - (tract_number, patch_index, skymap_name) references :ref:`Patch` (tract_number, index, skymap_name)

May be implemented as:

.. code:: sql

    CREATE VIEW VisitPatchJoin AS
    SELECT DISTINCT
        visit_number,
        camera_name,
        tract_number,
        patch_index,
        skymap_name
    FROM
        SensorPatchJoin;


.. _sql_VisitTractJoin:

VisitTractJoin
^^^^^^^^^^^^^^
Fields:
    +------------------------+---------+----------+
    | visit_number           | int     | NOT NULL |
    +------------------------+---------+----------+
    | camera_name            | varchar | NOT NULL |
    +------------------------+---------+----------+
    | tract_number           | int     | NOT NULL |
    +------------------------+---------+----------+
    | skymap_name            | varchar | NOT NULL |
    +------------------------+---------+----------+

Foreign Keys:
    - (visit_number, camera_name) references :ref:`Visit` (visit_number, camera_name)
    - (tract_number, skymap_name) references :ref:`Tract` (tract_number, skymap_name)

May be implemented as:

.. code:: sql

    CREATE VIEW VisitTractJoin AS
    SELECT DISTINCT
        visit_number,
        camera_name,
        tract_number,
        skymap_name
    FROM
        SensorPatchJoin;
