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

   For now, a WIP scratch pad for new data access APIs.


.. _Purpose:

Purpose
=======

This document describes a possible design for the LSST data access system.


.. _concepts_and_interfaces:

Concepts and Interfaces
=======================

This section describes the different concepts and interfaces in the data access system,
and the relations between them.


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

When implemented, its interface supports the following operation:

- `assemble(ConcreteDataset, components=[ConcreteDataset, ...], parameters=None) -> ConcreteDataset`

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

A unique identifier for a :ref:`Dataset` across :ref:`Data Repositories <Repository>`.  A :ref:`DatasetRef` is conceptually just combination of a :ref:`DatasetType` and a tuple of :ref:`DataUnits <DataUnit>`.

In the :ref:`Common Schema <CommonSchema>`, a :ref:`DatasetRef` is a row in the table for its :ref:`DatasetType`, with a foreign key field pointing to a :ref:`DataUnit` row for each element in tuple of :ref:`DataUnits <DataUnit>`.


.. _Repository:

Repository
----------

An entity that has the following three properties:

- Has at most one :ref:`Dataset` per :ref:`DatasetRef`.
- Has a unique identifier (i.e. :ref:`RepositoryTag`).
- Provides enough info to obtain a globally (across repositories) unique :ref:`Uri` given a :ref:`DatasetRef`.


.. _RepositoryTag:

RepositoryTag
-------------

Unique identifier of a :ref:`Repository` within a :ref:`RepositoryDatabase`.


.. _DatasetExpression:

DatasetExpression
-----------------

Is an expression (SQL query against a :ref:`Common Schema <CommonSchema>`) that can be evaluated to yield one or more unique :ref:`DatasetRefs <DatasetRef>` and their relations (in a :ref:`DataGraph`).

An open question is if it is sufficient to only allow users to vary the ``WHERE`` clause of the SQL query, or if custom joins are also required.


.. _DataGraph:

DataGraph
---------

A graph in which the nodes are :ref:`DatasetRefs <DatasetRef>` and :ref:`DataUnits <DataUnit>`, and the edges are the relations between them.

.. _Uri:

Uri
---

A standard Uniform Resource Identifier pointing to a :ref:`ConcreteDataset` in a :ref:`RepositoryDatastore`.

The :ref:`Dataset` pointed to may be **primary** or a :ref:`Component <DatasetComponents>` of a **composite**, but should always be serializable on its own.
When supported by the :ref:`RepositoryDatastore` the query part of the Uri (i.e. the part behind the optional question mark) may be used for continuous subsets (e.g. a region in an image).

.. _DatasetComponents:

DatasetComponents
-----------------

A dictionary of named components in a **composite** :ref:`Dataset`.
The entries in the dictionary are of `str : (Uri, DatasetMetatype)` type.


.. _RepositoryDatabase:

RepositoryDatabase
------------------

A SQL database (e.g. `PostgreSQL`, `MySQL` or `SQLite`) that provides one or more
realizations of the :ref:`Common Schema <CommonSchema>`.

The interface to this supports the following two methods:

- `getRepositoryRegistry(RepositoryTag) -> RepositoryRegistry`
  Obtain a :ref:`RepositoryRegistry` for a given :ref:`RepositoryTag`.
- `merge([RepositoryTag, ...]) -> RepositoryTag`
  Create a new (virtual, although all repositories are virtual in some sense) :ref:`Repository`
  with a new :ref:`RepositoryTag` by merging all :ref:`DatasetRefs <DatasetRef>`.

.. note::

   Multiple :ref:`Data Repositories <Repository>`, can be served from a single :ref:`RepositoryDatabase`
   using tags (TBD if this should be part of the :ref:`CommonSchema`).


.. _RepositoryDatastore:

RepositoryDatastore
-------------------

An entity that stores the actual data. This may be a (shared) filesystem, an object store
or some other system.

The interface to this supports the following methods:

- `get(Uri, parameters=None) -> ConcreteDataset`
- `put(ConcreteDataset, DatasetMetatype, Path) -> Uri`

.. _ScratchSpace:

ScratchSpace
------------

An entity that serves as temporary (volitile) storage for any kind of data that is
not (yet) in a :ref:`RepositoryDatabase` or a :ref:`RepositoryDatastore`.

.. _RepositoryHost:

RepositoryHost
--------------

Is an entity that is the combination of a :ref:`RepositoryDatabase`, a :ref:`RepositoryDatabase`
and (optionally) :ref:`ScratchSpace`.

.. _RepositoryRegistry:

RepositoryRegistry
------------------

Is the software component that sits on top of a :ref:`RepositoryDatabase` and provides the following API:

`addDataset(DatasetRef, Uri, DatasetComponents, Quantum=None) -> None`

  Add a :ref:`Dataset`. Optionally indicates which :ref:`Quantum` generated it.

`addQuantum(Quantum) -> None`

  Add a new :ref:`Quantum`.

`find(DatasetRef) -> Uri, DatasetMetatype, DatasetComponents`

  Lookup the location of :ref:`Dataset` associated with a `DatasetRef` in a :ref:`RepositoryDatastore`.
  Also return its :ref:`DatasetMetatype` and possible :ref:`DatasetComponents`.

`insertDataUnit(DataUnit, replace=False) -> None`

  Insert a new :ref:`DataUnit`, optionally replacing an existing one (for updates).

`makeDataGraph(DatasetExpression, [DatasetType, ...]) -> DataGraph`

  Evaluate a :ref:`DatasetExpression` given a list of :ref:`DatsetTypes <DatasetType>` and return a `DataGraph`.

`makePath(DatasetRef) -> Path`

  Construct the `Path` part of a :ref:`Uri`. This is often just a storage hint since
  the :ref:`RepositoryDatastore` will likely have to deviate from the provided path
  (in the case of an object-store for instance).
 
`registerDatasetType(DatasetType, template) -> None`

  Register a new :ref:`DatasetType`.
  
  .. todo::

      Clarify what a `template` means.

`subsetRepository(DatasetExpression, [DatasetType, ...]) -> RepositorySubsetDescription` (output undefined)

  Create a subset of a :ref:`Repository`.


.. _TransferClient:

TransferClient
--------------

Is the software component that initiates a transfer of data from a :ref:`RepositoryDatastore` to another :ref:`RepositoryDatastore` or :ref:`ScratchSpace`.
It has the following API:

- `retrieve({Uri : LocalPath}) -> None`
  Retrieves :ref:`Datasets <Dataset>` and stores them in the provided `LocalPath`.

.. todo::

    Needs updating


.. _InputOutputClient:

InputOutputClient
-----------------

Is the software componets that clients use to retrieve `Datasets <Dataset>` from a `RepositoryDatastore`.
It provides the following API:

- `get(Uri) -> ConcreteDatset`
- `put(ConcreteDataset, Path) -> Uri`
  store a :ref:`ConcreteDataset` at the location provided by `Path`.
  Actual storage location may be different and is returned as output `Uri`.

.. todo::

    Needs updating

.. ButlerConfiguration::


ButlerConfiguration
-------------------

Configuration for :ref:`Butler`. Wraps a YAML config file and provides:

- `dataRepositoryTag`.

.. Butler::

Butler
------

Holds a:

- :ref:`ButlerConfiguration` (`config`);
- :ref:`RepositoryDatastore` (optional, `RDS`);
- :ref:`RepositoryDatabase` (optional, `RDB`);

and provides:

* `get(DatasetRef, parameters=None) -> ConcreteDataset`

.. code:: python

    def get(datasetRef, parameters=None):
        RR = RDB.getRepositoryRegistry(config.dataRepositoryTag)
        uri, datasetMetatype, datasetComponents = RR.find(datasetRef)
        parent = RDS.get(uri, datsetMetatype, parameters) if uri else None
        children = {name : RDS.get(childUri, childMeta, parameters) for name, (childUri, childMeta) in datasetComponents.items()}
        return datasetMetatype.assemble(parent, children, parameters)

* `put(DatasetRef, ConcreteDataset, Quantum) -> None`

.. code:: python

    def put(datasetRef, concreteDataset, quantum=None):
        RR = RDB.getRepositoryRegistry(config.dataRepositoryTag)
        path = RR.makePath(datasetRef)
        datasetMetatype = RR.getDatasetMetatype(datasetRef)
        uri = RDS.put(concreteDataset, datasetMetatype, path)
        RR.addDataset(datasetRef, uri, datasetComponents, quantum)

* `getRepositoryRegistry() -> RepositoryRegistry`

.. code:: python

    def getRepositoryRegistry():
        return RDB.getRepositoryRegistry(config.dataRepositoryTag)

.. StorageButler::

StorageButler
-------------

Is a :ref:`Butler` that only provides `get` and `put`. It does
not hold a :ref:`RepositoryDatabase` and may or may not
hold a :ref:`RepositoryDatastore`.

.. _CommonSchema:

Common Schema
=============

The Common Schema is a set of conceptual SQL tables (which may be implemented
as views) that can be used to retrieve :ref:`DataUnit` and :ref:`Dataset`
metadata in any :ref:`Repository`.  Implementations may choose to add
fields to any of the tables described below, but they must have at least the
fields shown here.  The SQL dialect used to construct queries against the
Common Schema is TBD; because different implementations may use different
database systems, we can in general only support a limited common dialect.

The relationship between databases and :ref:`DataRepositories
<Repository>` may be one-to-many or one-to-one in different
implementations, but the Common Schema only provides a view to a single
:ref:`Repository` (except for the tables in the :ref:`Provenance
<cs_provenance>` section).  As a result, for most implementations that take
the one- to-many approach, at least some of the conceptual tables below must
be implemented as views that select only the entries that correspond to a
particular :ref:`Repository`.  We will refer to them as "tables" in the
rest of this system only for brevity.

The common schema is only intended to be used for SELECT queries.  Operations
that add or remove :ref:`DataUnits <DataUnit>` or :ref:`Datasets <Dataset>` (or
types thereof) to/from a :ref:`Repository` will be supported through 
Python APIs, but the SQL behind these APIs will in general be specific to the
actual (private) schema used to implement the data repository and possibly the
database system and its associated SQL dialect.

.. _cs_camera_dataunits:

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
hardware) should still correspond to a single row in this table.


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
AbstractFilter is the only DataUnit not associated with either a Camera or a
SkyMap.

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
Because some cameras identify sensors with string names and other use numbers,
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

.. _cs_skymap_dataunits:

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

.. _cs_calibration_dataunits:

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

.. _cs_dataunit_joins:

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


.. _cs_datasets:

Datasets
--------

Because the :ref:`DatasetTypes <DatasetType>` present in a
:ref:`Repository` may vary from repository to repository, the
:ref:`Dataset` tables in the Common Schema are defined dynamically according to
a set of rules:

 - There is a table for each :ref:`DatasetType`, with entries corresponding to
   :ref:`Datasets <Dataset>` that are present in the :ref:`Repository` (and
   only these).

 - The name of the table should be the name of the :ref:`DatasetType`.

 - The table has a foreign key field relating to each :ref:`DataUnit` table that
   is used to label the :ref:`DatasetType`.

 - The table has at least the following additional fields:

+------------+--------+---------------------------------------------+
| dataset_id | uint64 | PRIMARY KEY REFERENCES Dataset (dataset_id) |
+------------+--------+---------------------------------------------+
| uri        | str    |                                             |
+------------+--------+---------------------------------------------+

The ``dataset_id`` field is both a primary key that must be unique across
elements in this table and a link to the more general Dataset table described in
the :ref:`Provenance <cs_Provenance>` section; this means that it must be
globally unique across *all* dataset tables, virtually guaranteeing that these
per-:ref:`DatasetType` tables will be implemented as views into a larger table.

The ``uri`` field contains a string that can be used to local the file or other
entity that contains the stored :ref:`Dataset`.  While this may be generated
differently according to different configurations when the file is first
written, after it is written we do not expect the name to change and hence
record it in the database; this reduces the need for implementations to
be aware of past configurations in addition to their current confirguration. For
multi-file composite datasets, this field should be NULL, and another table
(TBD) can be used to associate the composite with its leaf-node :ref:`Datasets
<Dataset>`.


.. _cs_provenance:

Provenance
----------

Provenance queries frequently involve crossing :ref:`Repository` boundaries;
the inputs to a task that produced a particular :ref:`Dataset` may not be
present in the same repository that contains that :ref:`Dataset`.  As a result,
the tables in this section are not restricted to the contents of a single
:ref:`Repository`.

+-----------------+--------+----------------------------------------+
| *DatasetType*                                                     |
+=================+========+========================================+
| dataset_type_id | uint64 | PRIMARY KEY                            |
+-----------------+--------+----------------------------------------+
| name            | str    | NOT NULL UNIQUE                        |
+-----------------+--------+----------------------------------------+

+-------------+--------+---------------------------------+
| *Dataset*                                              |
+=============+========+=================================+
| dataset_id  | uint64 | PRIMARY KEY                     |
+-------------+--------+---------------------------------+
| uri         | str    |                                 |
+-------------+--------+---------------------------------+
| producer_id | uint64 | REFERENCES Quantum (quantum_id) |
+-------------+--------+---------------------------------+

These tables provide another view of the information in the
per-:ref:`DatasetType` tables described in the :ref:`Datasets <cs_datasets>`
section, with the following differences:

 - They provide no way to join with :ref:`DataUnit` tables (aside from joining
   with the per-:ref:`DatasetType` tables themselves on the ``dataset_id``
   field).

 - The Dataset table must contain entries for at least all :ref:`Datasets
   <Dataset>` in the :ref:`Repository`, but it may contain entries for
   additional :ref:`Datasets <Dataset>` as well.

 - These add the ``producer_id`` field, which records the Quantum that produced
   the dataset (if applicable).

+-------------+--------+---------------------------------+
| *Quantum*                                              |
+=============+========+=================================+
| quantum_id  | uint64 | PRIMARY KEY                     |
+-------------+--------+---------------------------------+
| config_id   | uint64 | REFERENCES Dataset (dataset_id) |
+-------------+--------+---------------------------------+
| env_id      | uint64 | REFERENCES Dataset (dataset_id) |
+-------------+--------+---------------------------------+
| task_name   | str    |                                 |
+-------------+--------+---------------------------------+

+-------------+--------+---------------------------------------------+
| *DatasetConsumer*                                                  |
+=============+========+=============================================+
| quantum_id  | uint64 | NOT NULL REFERENCES Quantum (quantum_id)    |
+-------------+--------+---------------------------------------------+
| dataset_id  | uint64 | NOT NULL REFERENCES Dataset (dataset_id)    |
+-------------+--------+---------------------------------------------+

A Quantum (a term borrowed from the SuperTask design) is a discrete unit of
work, such as a single invocation of ``SuperTask.runQuantum``.  It may also be
used here to describe other actions that produce and/or consume :ref:`Datasets
<Dataset>`.  The ``config_id`` and ``env_id`` provide links to :ref:`Datasets
<Dataset>` that hold the configuration and a description of the software and
compute environments.

Because each :ref:`Dataset` can have multiple consumers but at most one
producer, the Quantum that produces a Dataset is recorded in the
Dataset table itself, while the separate join table DatasetConsumers is
used to record the Quantum entries that utilized a Dataset entry.

There is no guarantee that the full provenance of a :ref:`Dataset` is captured
by these tables in a particular :ref:`Repository`, unless the :ref:`Dataset`
and all of its dependencies (any datasets consumed by its producer Quantum,
recursively) are also in the :ref:`Repository`.  When this is not the case,
the provenance information *may* be present (with dependencies included in the
Dataset table), or the ``Dataset.producer_id`` field may be null.  The Dataset
table may also contain entries that are not related at all to those in the
:ref:`Repository`; we have no obvious use for such a restriction, and it is
potentially burdensome on implementations.

.. note::

   As with everything else in the Common Schema, the provenance system used in
   the operations data backbone will almost certainly involve additional fields
   and tables, and what's in the Common Schema will just be a view.  But
   provenance tables here are even more of a blind straw-man than the rest of
   the Common Schema (which is derived more directly from SuperTask
   requirements), and I certainly expect it to change based on feedback; I
   think this reflects all that we need outside the operations system, but how
   operations implements their system should probably influence the details
   (such as how we represent configuration and software environment information).


.. .. rubric:: References

.. Make in-text citations with: :cite:`bibkey`.

.. .. bibliography:: local.bib lsstbib/books.bib lsstbib/lsst.bib lsstbib/lsst-dm.bib lsstbib/refs.bib lsstbib/refs_ads.bib
..    :encoding: latex+latin
..    :style: lsst_aa
