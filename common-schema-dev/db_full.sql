--========================================================================
-- DATA UNITS
--
-- DataUnits apply to all repositories in the database.
--========================================================================

--------------------------------------------------------------------------
-- Camera DataUnits
--------------------------------------------------------------------------

CREATE TABLE Camera (
    camera_id int PRIMARY KEY,
    name varchar NOT NULL,
    UNIQUE (name)
);

CREATE TABLE AbstractFilter (
    abstract_filter_id int PRIMARY KEY,
    name varchar NOT NULL,
    UNIQUE (name)
);

CREATE TABLE PhysicalFilter (
    physical_filter_id int PRIMARY KEY,
    name varchar NOT NULL,
    camera_id int NOT NULL,
    abstract_filter_id int,
    FOREIGN KEY (camera_id) REFERENCES Camera (camera_id),
    FOREIGN KEY (abstract_filter_id) REFERENCES AbstractFilter (abstract_filter_id),
    UNIQUE (name, camera_id)
);

CREATE TABLE PhysicalSensor (
    physical_sensor_id int PRIMARY KEY,
    name varchar NOT NULL,  -- may be stringified int for some cameras
    number varchar NOT NULL,   -- either name or num may be used to identify
    camera_id int NOT NULL,
    group varchar,    -- raft for LSST, rotation group for HSC?
    purpose varchar,  -- science vs. wavefront vs. guide
    FOREIGN KEY (camera_id) REFERENCES Camera (camera_id),
    CONSTRAINT UNIQUE (name, camera_id)
);

CREATE TABLE Visit (
    visit_id int PRIMARY KEY,
    number int NOT NULL,
    camera_id int NOT NULL,
    physical_filter_id int NOT NULL,
    obs_begin datetime NOT NULL,
    obs_end datetime NOT NULL,
    region blob,
    FOREIGN KEY (camera_id) REFERENCES Camera (camera_id),
    FOREIGN KEY (physical_filter_id) REFERENCES PhysicalFilter (physical_filter_id),
    CONSTRAINT UNIQUE (num, camera_id)
);

CREATE TABLE ObservedSensor (
    observed_sensor_id int PRIMARY KEY,
    visit_id int NOT NULL,
    physical_sensor_id int NOT NULL,
    region blob,
    FOREIGN KEY (visit_id) REFERENCES Visit (visit_id),
    FOREIGN KEY (physical_sensor_id) REFERENCES PhysicalSensor (physical_sensor_id),
    CONSTRAINT UNIQUE (visit_id, physical_sensor_id)
);

CREATE TABLE Snap (
    snap_id int PRIMARY KEY,
    visit_id int PRIMARY KEY,
    index int NOT NULL,
    obs_begin datetime NOT NULL,
    obs_end datetime NOT NULL,
    FOREIGN KEY (visit_id) REFERENCES Visit (visit_id)
    CONSTRAINT UNIQUE (visit_id, index)
);

--------------------------------------------------------------------------
-- SkyMap DataUnits
--------------------------------------------------------------------------

CREATE TABLE SkyMap (
    skymap_id int PRIMARY KEY,
    name varchar NOT NULL,
    CONSTRAINT UNIQUE (name)
);

CREATE TABLE Tract (
    tract_id int PRIMARY KEY,
    number int NOT NULL,
    skymap_id int NOT NULL,
    region blob,
    FOREIGN KEY (skymap_id) REFERENCES SkyMap (skymap_id),
    CONSTRAINT UNIQUE (skymap_id, num)
);

CREATE TABLE Patch (
    patch_id int PRIMARY KEY,
    tract_id int NOT NULL,
    index int NOT NULL,
    region blob,
    FOREIGN KEY (tract_id) REFERENCES Tract (tract_id),
    CONSTRAINT UNIQUE (tract_id, index)
);

--------------------------------------------------------------------------
-- Calibration DataUnits
--------------------------------------------------------------------------

CREATE TABLE MasterCalib (
    master_calib_id int PRIMARY KEY,
    camera_id int NOT NULL,
    FOREIGN KEY (camera_id) REFERENCES Camera (camera_id),
    FOREIGN KEY (physical_filter_id) REFERENCES PhysicalFilter (physical_filter_id),
    CONSTRAINT UNIQUE (first_visit, last_visit, camera_id, physical_filter_id)
);

--------------------------------------------------------------------------
-- Join tables between DataUnits
--
-- The spatial join tables are calculated, and may be implemented as views
-- if those calculations can be done within the database efficiently.
-- The MasterCalibVisitJoin table is not calculated; its entries should
-- be added whenever new MasterCalib entries are added
--------------------------------------------------------------------------

CREATE TABLE MasterCalibVisitJoin (
    master_calib_id int NOT NULL,
    visit_id int,
    FOREIGN KEY (master_calib_id) REFERENCES MasterCalib (master_calib_id),
    FOREIGN KEY (visit_id) REFERENCES Visit (visit_id)
);

CREATE TABLE SensorTractJoin (
    observed_sensor_id int NOT NULL,
    tract_id int NOT NULL,
    FOREIGN KEY (observed_sensor_id) REFERENCES ObservedSensor (observed_sensor_id),
    FOREIGN KEY (tract_id) REFERENCES Tract (tract_id),
    CONSTRAINT UNIQUE (observed_sensor_id, tract_id)
);

CREATE TABLE SensorPatchJoin (
    observed_sensor_id int NOT NULL,
    patch_id int NOT NULL,
    FOREIGN KEY (observed_sensor_id) REFERENCES ObservedSensor (unit_id),
    FOREIGN KEY (patch_id) REFERENCES Patch (unit_id),
    CONSTRAINT UNIQUE (observed_sensor_id, patch_id)
);

CREATE TABLE VisitTractJoin (
    visit_id int NOT NULL,
    tract_id int NOT NULL,
    FOREIGN KEY (visit_id) REFERENCES Visit (visit_id),
    FOREIGN KEY (tract_id) REFERENCES Tract (tract_id),
    CONSTRAINT UNIQUE (visit_id, tract_id)
);

CREATE TABLE VisitPatchJoin (
    visit_id int NOT NULL,
    patch_id int NOT NULL,
    FOREIGN KEY (visit_id) REFERENCES Visit (visit_id),
    FOREIGN KEY (patch_id) REFERENCES Patch (patch_id),
    CONSTRAINT UNIQUE (visit_id, patch_id)
);

--========================================================================
-- DATASETS
--
-- Dataset and DatasetType records are both associated with RepositoryTags.
-- DatasetMetatypes are global (to the full codebase, not just a Database).
-- Other tables here are associated with RepositoryTags implicitly through
-- Dataset and DatasetType.
--========================================================================

--------------------------------------------------------------------------
-- DatasetTypes and MetaType
--------------------------------------------------------------------------

CREATE TABLE DatasetMetatype (
    metatype_id int PRIMARY KEY,
    name varchar NOT NULL
);

CREATE TABLE DatasetMetatypeComposition (
    parent_id int NOT NULL,
    component_id int NOT NULL,
    component_name varchar NOT NULL,
    FOREIGN KEY (parent_id) REFERENCES DatasetMetatype (dataset_metatype_id),
    FOREIGN KEY (component_id) REFERENCES DatasetMetatype (dataset_metatype_id)
);

CREATE TABLE DatasetType (
    dataset_type_id int PRIMARY KEY,
    name varchar NOT NULL,
    template varchar,  -- pattern used to generate filenames from DataUnit fields
    dataset_metatype_id int NOT NULL,
    FOREIGN KEY (dataset_metatype_id) REFERENCES DatasetMetatype (dataset_metatype_id)
);

CREATE TABLE DatasetTypeUnits (
    dataset_type_id int PRIMARY KEY,
    unit_name varchar NOT NULL
);

--------------------------------------------------------------------------
-- Datasets
--
-- There's table for the entire Database, so IDs are unique even across
-- Repositories.  The dataref_pack field contains an ID that is unique
-- only with a repository, constructed by packing together the associated
-- units (the 'path' string passed to DataStore.put would be a viable but
-- probably inefficient choice).
--------------------------------------------------------------------------

CREATE TABLE Dataset (
    dataset_id int PRIMARY KEY,
    dataset_type_id NOT NULL,
    dataref_pack binary NOT NULL, -- packing of unit IDs to make a unique-with-repository label
    uri varchar,
    producer_id int,
    FOREIGN KEY (producer_id) REFERENCES Quantum (quantum_id),
    FOREIGN KEY (parent_dataset_id) REFERENCES Dataset (dataset_id)
);

--------------------------------------------------------------------------
-- Provenance
--------------------------------------------------------------------------

CREATE TABLE Quantum (
    quantum_id int PRIMARY KEY,
    task varchar,
    config_id int NOT NULL,
    -- other provenance information
    FOREIGN KEY (config_id) REFERENCES Dataset (dataset_id)
);

--------------------------------------------------------------------------
-- Composite Datasets
--
--  - If a virtual Dataset was created by writing multiple component Datasets,
--    the parent DatasetType's 'template' field and the parent Dataset's 'uri'
--    field may be null (depending on whether there was a also parent Dataset
--    stored whose components should be overridden).
--
--  - If a single Dataset was written and we're defining virtual components,
--    the component DatasetTypes should have null 'template' fields, but the
--    component Datasets will have non-null 'uri' fields with values created
--    by the Datastore
--------------------------------------------------------------------------

CREATE TABLE DatasetComposition (
    parent_id int NOT NULL,
    component_id int NOT NULL,
    component_name int NOT NULL,
    FOREIGN KEY (parent_id) REFERENCES Dataset (dataset_id),
    FOREIGN KEY (component_id) REFERENCES Dataset (dataset_id)
);

--------------------------------------------------------------------------
-- Tags to define multiple repos in a single database
--
-- In a single-repository database, these tables would simply be absent.
--------------------------------------------------------------------------

CREATE TABLE RepositoryTag (
    repository_tag_id int PRIMARY KEY,
    name varchar NOT NULL,
    CONSTRAINT UNIQUE (name)
);

CREATE TABLE DatasetRepositoryTagJoin (
    repository_tag_id int PRIMARY KEY,
    dataset_id int NOT NULL,
    FOREIGN KEY (repository_tag_id) REFERENCES RepositoryTag (repository_tag_id),
    FOREIGN KEY (dataset_id) REFERENCES Dataset (dataset_id)
);

CREATE TABLE DatasetTypeRepositoryTagJoin (
    repository_tag_id int PRIMARY KEY,
    dataset_type_id int NOT NULL,
    FOREIGN KEY (repository_tag_id) REFERENCES RepositoryTag (repository_tag_id),
    FOREIGN KEY (dataset_type_id) REFERENCES DatasetType (dataset_type_id)
);

--------------------------------------------------------------------------
-- Dataset-DataUnit joins
--------------------------------------------------------------------------

CREATE TABLE PhysicalFilterDatasetJoin (
    physical_filter_id int NOT NULL,
    dataset_id int NOT NULL,
    FOREIGN KEY (physical_filter_id) REFERENCES PhysicalFilter (physical_filter_id),
    FOREIGN KEY (dataset_id) REFERENCES Dataset (dataset_id)
);

CREATE TABLE PhysicalSensorDatasetJoin (
    physical_sensor_id int NOT NULL,
    dataset_id int NOT NULL,
    FOREIGN KEY (physical_sensor_id) REFERENCES PhysicalSensor (physical_sensor_id),
    FOREIGN KEY (dataset_id) REFERENCES Dataset (dataset_id)
);

CREATE TABLE VisitDatasetJoin (
    visit_id int NOT NULL,
    dataset_id int NOT NULL,
    FOREIGN KEY (visit_id) REFERENCES Visit (visit_id),
    FOREIGN KEY (dataset_id) REFERENCES Dataset (dataset_id)
);

CREATE TABLE ObservedSensorDatasetJoin (
    observed_sensor_id int NOT NULL,
    dataset_id int NOT NULL,
    FOREIGN KEY (observed_sensor_id) REFERENCES ObservedSensor (observed_sensor_id),
    FOREIGN KEY (dataset_id) REFERENCES Dataset (dataset_id)
);

CREATE TABLE SnapDatasetJoin (
    snap_id int NOT NULL,
    dataset_id int NOT NULL,
    FOREIGN KEY (snap_id) REFERENCES Snap (snap_id),
    FOREIGN KEY (dataset_id) REFERENCES Dataset (dataset_id)
);

CREATE TABLE AbstractFilterDatasetJoin (
    abstract_filter_id int NOT NULL,
    dataset_id int NOT NULL,
    FOREIGN KEY (abstract_filter_id) REFERENCES AbstractFilter (abstract_filter_id),
    FOREIGN KEY (dataset_id) REFERENCES Dataset (dataset_id)
);

CREATE TABLE TractDatasetJoin (
    tract_id int NOT NULL,
    dataset_id int NOT NULL,
    FOREIGN KEY (tract_id) REFERENCES Tract (tract_id),
    FOREIGN KEY (dataset_id) REFERENCES Dataset (dataset_id)
);

CREATE TABLE PatchDatasetJoin (
    patch_id int NOT NULL,
    dataset_id int NOT NULL,
    FOREIGN KEY (patch_id) REFERENCES Patch (patch_id),
    FOREIGN KEY (dataset_id) REFERENCES Dataset (dataset_id)
);

