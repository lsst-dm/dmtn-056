..
  Technote content.

  See https://developer.lsst.io/docs/rst_styleguide.html
  for a guide to reStructuredText writing.

  Do not put the title, authors or other metadata in this document;
  those are automatically added.

  Use the following syntax for sections:

  Sections
  ========

  and

  Subsections
  -----------

  and

  Subsubsections
  ^^^^^^^^^^^^^^

  To add images, add the image file (png, svg or jpeg preferred) to the
  _static/ directory. The reST syntax for adding the image is

  .. figure:: /_static/filename.ext
     :name: fig-label

     Caption text.

   Run: ``make html`` and ``open _build/html/index.html`` to preview your work.
   See the README at https://github.com/lsst-sqre/lsst-technote-bootstrap or
   this repo's README for more info.

   Feel free to delete this instructional comment.

:tocdepth: 1

.. Please do not modify tocdepth; will be fixed when a new Sphinx theme is shipped.

.. sectnum:: :depth: 1

.. Add content below. Do not include the document title.

.. note::

   **This technote is not yet published.**

   For now, a WIP scratch pad for new Butler APIs.


.. _Purpose:

Purpose
=======

This document describes a possible abstract design for the buter to facilitate discussions. It does not map directly to actual code, but rather serves to clarify our thinking on the concepts.


.. _Components:

Components
==========


.. _Dataset:

Dataset
-------

Represents a single entity of data, with associated metadata (e.g. a particular ``calexp`` for a particular instrument corresponding to a particular visit and sensor).


.. _DatasetType:

DatasetType
-----------

The conceptual type of which :ref:`Datasets <Dataset>` are instances (e.g. ``calexp``).


.. _ConcreteDataset:

ConcreteDataset
---------------

The in-memory manifestation of a :ref:`Dataset` (e.g. an ``afw::image::Exposure`` with the contents of a particular ``calexp``).


.. _DatasetMetatype:

DatasetMetatype
---------------

A category of :ref:`DatasetTypes <DatasetType>` that utilize the same in-memory classes for their :ref:`ConcreteDatasets <ConcreteDataset>` and can be saved to the same file format(s).


.. _DataUnit:

DataUnit
--------

Represents a discrete unit of data (e.g. a particular visit, tract, or filter).

In the :ref:`Common Schema <CommonSchema>`, a :ref:`DataUnit` is a row in the table for its :ref:`DataUnitType`.  :ref:`DataUnits <DataUnit>` must be shared across different repositories (which may be backed by different database systems), so their primary keys in the :ref:`CommonSchema` must not be database-specific quantities such as autoincrement fields.


.. _DataUnitType:

DataUnitType
------------

The conceptual type of a :ref:`DataUnit` (such as visit, tract, or filter).

In the :ref:`Common Schema <CommonSchema>`, each :ref:`DataUnitType` is a table that the holds :ref:`DataUnits <DataUnit>` of that type as its rows.


.. _DatasetRef:

DatasetRef
----------

A unique identifier for a :ref:`Dataset` across :ref:`Data Repositories <DataRepository>`.  A :ref:`DatasetRef` is conceptually just combination of a :ref:`DatasetType` and a tuple of :ref:`DataUnits <DataUnit>`.

In the :ref:`Common Schema <CommonSchema>`, a :ref:`DatasetRef` is a row in the table for its :ref:`DatasetType`, with a foreign key field pointing to a :ref:`DataUnit` row for each element in tuple of :ref:`DataUnits <DataUnit>`.


.. _DataRepository:

DataRepository
--------------

An entity that one can point a butler to that has the following three properties:

- Has at most one :ref:`Dataset` per :ref:`DatasetRef`.
- Has a label that humans can parse (i.e. :ref:`DataRepositoryRef`)
- Provides enough info to a make globally (across repositories) unique filename (or key for an object store) given a :ref:`DatasetRef`.


.. _DataRepositoryRef:

DataRepositoryRef
-----------------

Globally unique, human parseable, identifier of a :ref:`DataRepository` (e.g. the path to it or a URI).


.. _DatasetExpression:

DatasetExpression
-----------------

Is an expression (SQL query against a :ref:`Common Schema <CommonSchema>`) that can be evaluated by an :ref:`AssociationButler` to yield one or more unique :ref:`DatasetRefs <DatasetRef>` and their relations (in a :ref:`DataGraph`).

An open question is if it is sufficient to only allow users to vary the ``WHERE`` clause of the SQL query, or if custom joins are also required.


.. _DataGraph:

DataGraph
---------

A graph in which the nodes are :ref:`DatasetRefs <DatasetRef>` and :ref:`DataUnits <DataUnit>`, and the edges are the relations between them.


.. _Butlers:

Butlers
=======

define interfaces to abstract away serialization/deserialization of :ref:`ConcreteDatasets <ConcreteDataset>`.
Additionally some, but not all, :ref:`Butlers` allow particular :ref:`Datasets <Dataset>` (and relations between them) to be retrieved by a (metadata) query (i.e. :ref:`DatasetExpression`).


.. _PrimitiveButler:

PrimitiveButler
---------------

Abstract interface that has two methods:

- ``get(Key k) -> ConcreteDataset``
- ``put(Key k, ConcreteDataset obj) -> None``

where :ref:`ConcreteDataset` is any kind of in-memory object supported by the butler.
The `Key` type is implementation specific and may be a filename or a hash for an object store.

The input and output :ref:`ConcreteDataset` are always bitwise identical. Transformations are to be handled by higher level wrappers (that may expose the same interface).

Backend storage is not defined by this interface. Different :ref:`PrimitiveButler` implementations may write to single/multiple (FITS/HDF5) files, (no)sql-databases, object stores, etc. They may even delegate part of the work to other concrete :ref:`PrimitiveButlers <PrimitiveButler>`.


.. _StorageButler:

StorageButler
-------------

Abstract interface that has two methods:

- ``get(DatasetRef dr) -> ConcreteDataset``
- ``put(DatasetRef dr, ConcreteDataset obj) -> None``

where :ref:`ConcreteDataset` is any kind of in-memory object supported by the butler.

In practice delegates the actual IO to a lower level butler which may be another :ref:`StorageButler` or a :ref:`PrimitiveButler` (in which case it will map the :ref:`DatasetRef` to a Key).


.. _AssociationButler:

AssociationButler
-----------------

Has one method:

- ``evaluateExpression(List<DatasetTypes> types, DatasetExpression expression) -> DataGraph``

Presents the user with the :ref:`CommonSchema` (a set of tables) that the :ref:`DatasetExpression` can be evaluated against to yied a graph of unique :ref:`DatasetRefs <DatasetRef>` with their relations (this is typically a subset of the full repository graph).

In different implementations these tables may exist directly, as a pass-through to a ``SQLite``/``PostgreSQL``/``MySQL`` database that actually has them, or it may have to do some kind of mapping.

The point is that users/developers can write their SQL queries against this fixed schema.


.. _ConvenienceButler:

ConvenienceButler
-----------------

Wraps an :ref:`AssociationButler` with some tooling to build up a :ref:`DatasetExpression`. This may be a simple mini-language parser (e.g. for globs) or even some interactive tool.


.. _CommonSchema:

Common Schema
=============

The Common Schema is a set of conceptual SQL tables (which may be implemented
as views) that can be used to retrieve :ref:`DataUnit` and :ref:`Dataset`
metadata in any :ref:`DataRepository`.  Implementations may choose to add
fields to any of the tables described below, but they must have at least the
fields shown here.  The SQL dialect used to construct queries against the
Common Schema is TBD; because different implementations may use different
database systems, we can in general only support a limited common dialect.

The relationship between databases and :ref:`DataRepositories
<DataRepository>` may be one-to-many or one-to-one in different
implementations, so the Common Schema only provides a view to a single
:ref:`DataRepository`.  As a result, for most implementations that take the
one-to-many approach, at least some of the conceptual tables below must be
implemented as views that select only the entries that correspond to a
particular :ref:`DataRepository`.


Camera DataUnits
----------------

+------------+--------+-------------+
| *Camera*                          |
+============+========+=============+
| camera_id  | uint64 | PRIMARY KEY |
+------------+--------+-------------+
| name       | str    | UNIQUE      |
+------------+--------+-------------+

Entries in the Camera table are essentially just sources of raw data with a
constant layout of PhysicalSensors and a self-constent numbering system for
Visits.  Different versions of the same camera (due to e.g. changes in
hardware) should correspond to a single row in this table.


+----------------------+--------+----------------------+
| *AbstractFilter*                                     |
+======================+========+======================+
| abstract_filter_id   | uint64 | PRIMARY KEY          |
+----------------------+--------+----------------------+
| name                 | str    | NOT NULL UNIQUE      |
+----------------------+--------+----------------------+

+----------------------+--------+--------------------------------------------------+
| *PhysicalFilter*                                                                 |
+======================+========+==================================================+
| physical_filter_id   | uint64 | PRIMARY KEY                                      |
+----------------------+--------+--------------------------------------------------+
| name                 | str    | NOT NULL                                         |
+----------------------+--------+--------------------------------------------------+
| camera_id            | uint64 | NOT NULL REFERENCES Camera (camera_id)           |
+----------------------+--------+--------------------------------------------------+
| abstract_filter_id   | uint64 | REFERENCES AbstractFilter (abstract_filter_id)   |
+----------------------+--------+--------------------------------------------------+
| UNIQUE (name, camera_id)                                                         |
+----------------------------------------------------------------------------------+

Entries in the PhysicalFilter table represent the bandpass filters that can be
associated with a particular visit.  These are different from AbstractFilters,
which are used to label Datasets that aggregate data from multiple Visits.
Having these two different DataUnits for filters is necessary to make it
possible to combine data from Visits taken with different filters.  A
PhysicalFilter may or may not be associated with a particular AbstractFilter.

+----------------------+--------+-----------------------------------------+
| *PhysicalSensor*                                                        |
+======================+========+=========================================+
| physical_sensor_id   | uint64 | PRIMARY KEY                             |
+----------------------+--------+-----------------------------------------+
| number               | uint16 |                                         |
+----------------------+--------+-----------------------------------------+
| name                 | str    | NOT NULL                                |
+----------------------+--------+-----------------------------------------+
| camera_id            | uint64 | NOT NULL REFERENCES Camera (camera_id)  |
+----------------------+--------+-----------------------------------------+
| group                | str    |                                         |
+----------------------+--------+-----------------------------------------+
| purpose              | str    | NOT NULL                                |
+----------------------+--------+-----------------------------------------+
| UNIQUE (number, camera_id)                                              |
+-------------------------------------------------------------------------+
| UNIQUE (name, camera_id)                                                |
+-------------------------------------------------------------------------+

PhysicalSensors actually represent the "slot" for a sensor in a camera,
independent of both any observations and the actual detector (which may change
over the life of the camera).  The ``group`` field may mean different things
for different cameras (such as rafts for LSST, or groups of sensors oriented
the same way relative to the focal plane for HSC).  The ``purpose`` field
indicates the role of the sensor (such as science, wavefront, or guiding).
Becaues some cameras identify sensors with string names and other use numbers,
we provide fields for both; the name may be a stringified integer, and the
number may be autoincrement.

+----------------------+----------+-----------------------------------------------------------+
| *Visit*                                                                                     |
+======================+==========+===========================================================+
| visit_id             | uint64   | PRIMARY KEY                                               |
+----------------------+----------+-----------------------------------------------------------+
| number               | uint64   | NOTNULL                                                   |
+----------------------+----------+-----------------------------------------------------------+
| camera_id            | uint64   | NOT NULL REFERENCES Camera (camera_id)                    |
+----------------------+----------+-----------------------------------------------------------+
| physical_filter_id   | uint64   | NOT NULL REFERENCES AbstractFilter (abstract_filter_id)   |
+----------------------+----------+-----------------------------------------------------------+
| obs_begin            | datetime | NOT NULL                                                  |
+----------------------+----------+-----------------------------------------------------------+
| obs_end              | datetime | NOT NULL                                                  |
+----------------------+----------+-----------------------------------------------------------+
| region               | blob     |                                                           |
+----------------------+----------+-----------------------------------------------------------+
| UNIQUE (number, camera_id)                                                                  |
+---------------------------------------------------------------------------------------------+

Entries in the Visit table correspond to observations with the full camera at
a particular pointing, possibly comprised of multiple exposures (Snaps).  A
Visit's ``region`` field holds an approximate but inclusive representation of
its position on the sky that can be compared to the ``regions`` of other
DataUnits.

+----------------------+--------+-----------------------------------------------------------+
| *ObservedSensor*                                                                          |
+======================+========+===========================================================+
| observed_sensor_id   | uint64 | PRIMARY KEY                                               |
+----------------------+--------+-----------------------------------------------------------+
| physical_sensor_id   | uint64 | NOT NULL REFERENCES PhysicalSensor (physical_sensor_id)   |
+----------------------+--------+-----------------------------------------------------------+
| visit_id             | uint64 | NOT NULL REFERENCES Visit (visit_id)                      |
+----------------------+--------+-----------------------------------------------------------+
| region               | blob   |                                                           |
+----------------------+--------+-----------------------------------------------------------+
| UNIQUE (physical_sensor_id, visit_id)                                                     |
+-------------------------------------------------------------------------------------------+

An ObservedSensor is simply a combination of a Visit and a PhysicalSensor, but
unlike most other DataUnit combinations (which are not typically DataUnits
themselves), this one is both ubuiquitous and contains additional information:
a ``region`` that represents the position of the observed sensor image on the
sky.

+----------------------------+----------+---------------------------------------+
| *Snap*                                                                        |
+============================+==========+=======================================+
| snap_id                    | uint64   | PRIMARY KEY                           |
+----------------------------+----------+---------------------------------------+
| number                     | uint16   | NOT NULL                              |
+----------------------------+----------+---------------------------------------+
| visit_id                   | uint64   | NOT NULL REFERENCES Visit (visit_id)  |
+----------------------------+----------+---------------------------------------+
| obs_begin                  | datetime | NOT NULL                              |
+----------------------------+----------+---------------------------------------+
| obs_end                    | datetime | NOT NULL                              |
+----------------------------+----------+---------------------------------------+
| UNIQUE (number, visit_id)                                                     |
+----------------------------+----------+---------------------------------------+

A Snap is a single-exposure subset of a Visit.  Most non-LSST Visits will have
only a single Snap.

SkyMap DataUnits
----------------

+------------+--------+-------------+
| *SkyMap*                          |
+============+========+=============+
| skymap_id  | uint64 | PRIMARY KEY |
+------------+--------+-------------+
| name       | str    | UNIQUE      |
+------------+--------+-------------+

Each SkyMap entry represents a different way to subdivide the sky into tracts
and patches, including any parameters involved in those defitions (i.e.
different configurations of the same ``lsst.skymap.BaseSkyMap`` subclass yield
different rows).  While SkyMaps need unique, human-readable names, it may also
be wise to add a hash or pickle of the SkyMap instance that defines the
mapping to avoid duplicate entries (not yet included).

+-----------------------------+--------+-----------------------------------------+
| *Tract*                                                                        |
+=============================+========+=========================================+
| tract_id                    | uint64 | PRIMARY KEY                             |
+-----------------------------+--------+-----------------------------------------+
| number                      | uint16 | NOT NULL                                |
+-----------------------------+--------+-----------------------------------------+
| skymap_id                   | uint64 | NOT NULL REFERENCES SkyMap (skymap_id)  |
+-----------------------------+--------+-----------------------------------------+
| region                      | blob   |                                         |
+-----------------------------+--------+-----------------------------------------+
| UNIQUE (number, skymap_id)                                                     |
+-----------------------------+--------+-----------------------------------------+

A Tract is a contiguous, simple area on the sky with a 2-d Euclidian
coordinate system defined by a single map projection.  If the parameters of
the sky projection and the Tract's various bounding boxes can be standardized
across all SkyMap implementations, it may be useful to include them in the
table as well.

+---------------------------+--------+----------------------------------------+
| *Patch*                                                                     |
+===========================+========+========================================+
| patch_id                  | uint64 | PRIMARY KEY                            |
+---------------------------+--------+----------------------------------------+
| index                     | uint16 | NOT NULL                               |
+---------------------------+--------+----------------------------------------+
| tract_id                  | uint64 | NOT NULL REFERENCES SkyMap (tract_id)  |
+---------------------------+--------+----------------------------------------+
| region                    | blob   |                                        |
+---------------------------+--------+----------------------------------------+
| UNIQUE (index, tract_id)                                                    |
+---------------------------+--------+----------------------------------------+

Tracts are subdivided into Patches, which share the Tract coordinate system
and define similarly-sized regions that overlap by a configurable amount.  As
with Tracts, we may want to include fields to describe Patch boundaries in this
table in the future.


Calibration DataUnits
---------------------

+---------------------------+--------+-------------------------------------------------+
| *CalibRange*                                                                         |
+===========================+========+=================================================+
| calib_range_id            | uint64 | PRIMARY KEY                                     |
+---------------------------+--------+-------------------------------------------------+
| first_visit               | uint64 | NOT NULL                                        |
+---------------------------+--------+-------------------------------------------------+
| last_visit                | uint64 |                                                 |
+---------------------------+--------+-------------------------------------------------+
| camera_id                 | uint64 | NOT NULL REFERENCES Camera (camera_id)          |
+---------------------------+--------+-------------------------------------------------+
| physical_filter_id        | uint64 | REFERENCES PhysicalFilter (physical_filter_id)  |
+---------------------------+--------+-------------------------------------------------+
| UNIQUE (first_visit, last_visit, camera_id, physical_filter_id)                      |
+---------------------------+--------+-------------------------------------------------+

+------------------------+--------+-----------------------------------------------------------+
| *SensorCalibRange*                                                                          |
+========================+========+===========================================================+
| sensor_calib_range_id  | uint64 | PRIMARY KEY                                               |
+------------------------+--------+-----------------------------------------------------------+
| first_visit            | uint64 | NOT NULL                                                  |
+------------------------+--------+-----------------------------------------------------------+
| last_visit             | uint64 |                                                           |
+------------------------+--------+-----------------------------------------------------------+
| physical_sensor_id     | uint64 | NOT NULL REFERENCES PhysicalSensor (physical_sensor_id)   |
+------------------------+--------+-----------------------------------------------------------+
| physical_filter_id     | uint64 | REFERENCES PhysicalFilter (physical_filter_id)            |
+------------------------+--------+-----------------------------------------------------------+
| UNIQUE (first_visit, last_visit, camera_id, physical_sensor_id, physical_filter_id)         |
+------------------------+--------+-----------------------------------------------------------+

Master calibration products are defined over a range of Visits from a given
Camera, though a range of observation dates could be utilized instead.
Calibration products may additionally be specialized for a particular
PhysicalFilter, or may be appropriate for all PhysicalFilters by setting the
``physical_filter_id`` field to ``NULL``.  Calibration products that are
defined for individual sensors should use ``SensorCalibRange``.

DataUnit Joins
--------------

The tables in this section represent many-to-many joins between DataUnits
defined in the previous section that can be generated programmatically.  These
join tables have no primary key (at least not as part of the common schema),
and hence cannot be used to label Datasets.

+------------------+--------+---------------------------------------------------+
| *CalibRangeJoin*                                                              |
+==================+========+===================================================+
| calib_range_id   | uint64 | NOT NULL REFERENCES CalibRange (calib_range_id)   |
+------------------+--------+---------------------------------------------------+
| visit_id         | uint64 | NOT NULL REFERENCES Visit (visit_id)              |
+------------------+--------+---------------------------------------------------+

+--------------------------+--------+-----------------------------------------------------------------+
| *SensorCalibRangeJoin*                                                                              |
+==========================+========+=================================================================+
| sensor_calib_range_id    | uint64 | NOT NULL REFERENCES SensorCalibRange (sensor_calib_range_id)    |
+--------------------------+--------+-----------------------------------------------------------------+
| observed_sensor_id       | uint64 | NOT NULL REFERENCES ObservedSensor (observed_sensor_id)         |
+--------------------------+--------+-----------------------------------------------------------------+

The above two tables define the joins between master calibration Datasets and
the observations they should be used to calibrate.  These can be defined
directly as views in on the DataUnit tables:

.. code-block:: sql

    CREATE VIEW CalibRangeJoin AS
        SELECT
            Visit.visit_id,
            CalibRange.calib_range_id
        FROM
            Visit INNER JOIN CalibRange ON (
                (Visit.num BETWEEN CalibRange.first_visit AND CalibRange.last_visit)
                AND Visit.physical_filter_id = CalibRange.physical_filter_id
            );

    CREATE VIEW SensorCalibRangeJoin
        SELECT
            ObservedSensor.observed_sensor_id,
            SensorCalibRange.sensor_calib_range_id
        FROM
            ObservedSensor INNER JOIN Visit ON (ObservedSensor.visit_id = Visit.visit_id)
            INNER JOIN SensorCalibRange ON (
                (Visit.num BETWEEN SensorCalibRange.first_visit AND SensorCalibRange.last_visit)
                AND Visit.physical_filter_id = SensorCalibRange.physical_filter_id
            );

The remaining join tables represent the spatial relationships between
observations and SkyMap entities; records should only be present in these
tables when the two entities overlap as defined by their ``region`` fields.

+----------------------+--------+-----------------------------------------------------------+
| *SensorPatchJoin*                                                                         |
+======================+========+===========================================================+
| observed_sensor_id   | uint64 | NOT NULL REFERENCES ObservedSensor (observed_sensor_id)   |
+----------------------+--------+-----------------------------------------------------------+
| patch_id             | uint64 | NOT NULL REFERENCES Patch (patch_id)                      |
+----------------------+--------+-----------------------------------------------------------+

+----------------------+--------+-----------------------------------------------------------+
| *SensorTractJoin*                                                                         |
+======================+========+===========================================================+
| observed_sensor_id   | uint64 | NOT NULL REFERENCES ObservedSensor (observed_sensor_id)   |
+----------------------+--------+-----------------------------------------------------------+
| tract_id             | uint64 | NOT NULL REFERENCES Tract (tract_id)                      |
+----------------------+--------+-----------------------------------------------------------+

+------------+--------+----------------------------------------+
| *VisitPatchJoin*                                             |
+============+========+========================================+
| visit_id   | uint64 | NOT NULL REFERENCES Visit (visit_id)   |
+------------+--------+----------------------------------------+
| patch_id   | uint64 | NOT NULL REFERENCES Patch (patch_id)   |
+------------+--------+----------------------------------------+

+------------+--------+----------------------------------------+
| *VisitTractJoin*                                             |
+============+========+========================================+
| visit_id   | uint64 | NOT NULL REFERENCES Visit (visit_id)   |
+------------+--------+----------------------------------------+
| tract_id   | uint64 | NOT NULL REFERENCES Tract (tract_id)   |
+------------+--------+----------------------------------------+


.. .. rubric:: References

.. Make in-text citations with: :cite:`bibkey`.

.. .. bibliography:: local.bib lsstbib/books.bib lsstbib/lsst.bib lsstbib/lsst-dm.bib lsstbib/refs.bib lsstbib/refs_ads.bib
..    :encoding: latex+latin
..    :style: lsst_aa
