--------------------------------------------------------------------------
-- Core Units
--------------------------------------------------------------------------

CREATE TABLE Camera (
    unit_id int PRIMARY KEY,
    name varchar NOT NULL,
    CONSTRAINT UNIQUE (name)
);

CREATE TABLE Filter (
    unit_id int PRIMARY KEY,
    name varchar NOT NULL,
    camera_id int,
    FOREIGN KEY (camera_id) REFERENCES Camera (unit_id),
    UNIQUE (name, camera_id)
);

CREATE TABLE PhysicalSensor (
    unit_id int PRIMARY KEY,
    name varchar NOT NULL,  -- may be stringified int for some cameras
    num varchar NOT NULL,   -- either name or num may be used to identify
    camera_id int NOT NULL,
    group varchar,    -- raft for LSST, rotation group for HSC?
    purpose varchar,  -- science vs. wavefront vs. guide
    FOREIGN KEY (camera_id) REFERENCES Camera (unit_id),
    CONSTRAINT UNIQUE (name, camera_id)
);

CREATE TABLE Visit (
    unit_id int PRIMARY KEY,
    num int NOT NULL,
    camera_id int NOT NULL,
    filter_id int NOT NULL,
    region SkyRegion,
    FOREIGN KEY (camera_id) REFERENCES Camera (unit_id),
    FOREIGN KEY (filter_id) REFERENCES Filter (unit_id),
    CONSTRAINT UNIQUE (num, camera_id)
);

CREATE TABLE ObservedSensor (
    unit_id int PRIMARY KEY,
    visit_id int NOT NULL,
    physical_id int NOT NULL,
    region SkyRegion,
    FOREIGN KEY (visit_id) REFERENCES Visit (unit_id),
    FOREIGN KEY (physical_id) REFERENCES PhysicalSensor (unit_id),
    CONSTRAINT UNIQUE (visit_id, physical_id)
    -- CONSTRAINT (Visit.camera_id = PhysicalSensor.camera_id)
);

CREATE TABLE Snap (
    unit_id int PRIMARY KEY,
    visit_id int PRIMARY KEY,
    index int NOT NULL,
    FOREIGN KEY (visit_id) REFERENCES Visit (unit_id)
    CONSTRAINT UNIQUE (visit_id, index)
);

CREATE TABLE SkyMap (
    unit_id int PRIMARY KEY,
    name varchar NOT NULL,
    CONSTRAINT UNIQUE (name)
);

CREATE TABLE Tract (
    unit_id int PRIMARY KEY,
    num int NOT NULL,
    skymap_id int NOT NULL,
    region SkyRegion,
    FOREIGN KEY (skymap_id) REFERENCES SkyMap (unit_id),
    CONSTRAINT UNIQUE (skymap_id, num)
);

CREATE TABLE Patch (
    unit_id int PRIMARY KEY,
    tract_id int NOT NULL,
    index int NOT NULL,
    region SkyRegion,
    FOREIGN KEY (tract_id) REFERENCES Tract (unit_id),
    CONSTRAINT UNIQUE (tract_id, index)
);

--------------------------------------------------------------------------
-- Calibration Units
--------------------------------------------------------------------------

CREATE TABLE CalibRange (
    unit_id int PRIMARY KEY,
    first_visit_num int NOT NULL,
    last_visit_num int,
    camera_id int,
    filter_id int,
    FOREIGN KEY (camera_id) REFERENCES Camera (unit_id),
    FOREIGN KEY (filter_id) REFERENCES Filter (unit_id),
    CONSTRAINT UNIQUE (first_visit, last_visit, camera_id, filter_id)
);


CREATE TABLE SensorCalibRange (
    unit_id int PRIMARY KEY,
    first_visit_num int NOT NULL,
    last_visit_num int,
    sensor_id int,
    filter_id int,
    FOREIGN KEY (sensor_id) REFERENCES PhysicalSensor (unit_id),
    FOREIGN KEY (filter_id) REFERENCES Filter (unit_id),
    CONSTRAINT UNIQUE (first_visit, last_visit, camera_id, filter_id)
    -- CONSTRAINT (PhysicalSensor.camera_id = Filter.camera_id OR Filter.camera_id is NULL)
);


--------------------------------------------------------------------------
-- Other DatasetIdentifiers
--------------------------------------------------------------------------

CREATE TABLE Raw (
    unit_id int PRIMARY KEY,
    snap_id int NOT NULL,
    sensor_id int NOT NULL,
    FOREIGN KEY (snap_id) REFERENCES Snap (unit_id),
    FOREIGN KEY (sensor_id) REFERENCES ObservedSensor (unit_id),
    CONSTRAINT UNIQUE (snap_id, sensor_id),
    -- CONSTRAINT (Snap.visit_id == ObservedSensor.visit_id)
);

CREATE TABLE Warp (
    unit_id int PRIMARY KEY,
    patch_id int NOT NULL,
    visit_id int NOT NULL,
    FOREIGN KEY (patch_id) REFERENCES Patch (unit_id),
    FOREIGN KEY (visit_id) REFERENCES Visit (unit_id),
    CONSTRAINT UNIQUE (patch_id, visit_id),
);

CREATE TABLE Coadd (
    unit_id int PRIMARY KEY,
    patch_id int NOT NULL,
    filter_id int,
    FOREIGN KEY (patch_id) REFERENCES Patch (unit_id),
    FOREIGN KEY (filter_id) REFERENCES Filter (filter_id),
    CONSTRAINT UNIQUE (patch_id, filter_id),
);


--------------------------------------------------------------------------
-- Datasets and Provenance
--------------------------------------------------------------------------

CREATE TABLE DatasetType (
    dataset_type_id int PRIMARY KEY,
    name varchar NOT NULL,
    unit_type varchar NOT NULL
);

CREATE TABLE Quantum (
    quantum_id int PRIMARY KEY,
    task varchar
    -- other provenance information
);

CREATE TABLE Dataset (
    dataset_id int PRIMARY KEY,
    dataset_type_id NOT NULL,
    producer_id int,
    FOREIGN KEY (producer_id) REFERENCES Quantum (quantum_id)
);

CREATE TABLE DatasetConsumers (
    dataset_id int NOT NULL,
    quantum_id int NOT NULL,
    FOREIGN KEY (dataset_id) REFERENCES Dataset (dataset_id)
    FOREIGN KEY (quantum_id) REFERENCES Quantum (quantum_id)
);

CREATE TABLE UnitDatasetJoin (
    unit_id int NOT NULL,
    unit_type varchar NOT NULL,  -- not needed if unit_ids are globally unique?
    dataset_id int NOT NULL,
    dataset_type_id int NOT NULL,
    FOREIGN KEY (dataset_id) REFERENCES Dataset (dataset_id),
    FOREIGN KEY (dataset_type_id) REFERENCES DatasetType (datset_type_id),
    -- CONSTRAINT (Dataset.DatasetType.unit_type = unit_type)
);


--------------------------------------------------------------------------
-- Tags for multiple repos in a single database
--------------------------------------------------------------------------

CREATE TABLE Tag (
    tag_id int PRIMARY KEY,
    name varchar,
    CONSTRAINT UNIQUE (name)
);

CREATE TABLE DatasetTagJoin (
    tag_id int PRIMARY KEY,
    dataset_id int NOT NULL,
    FOREIGN KEY (tag_id) REFERENCES Tag (tag_id),
    FOREIGN KEY (dataset_id) REFERENCES Dataset (dataset_id)
);



--------------------------------------------------------------------------
-- Spatial Join Materialization (derived from SkyRegion columns)
--------------------------------------------------------------------------

CREATE TABLE VisitTractOverlap (
    visit_id int NOT NULL,
    tract_id int NOT NULL,
    FOREIGN KEY (visit_id) REFERENCES Visit (unit_id),
    FOREIGN KEY (tract_id) REFERENCES Tract (unit_id)
);

CREATE TABLE VisitPatchOverlap (
    visit_id int NOT NULL,
    patch_id int NOT NULL,
    FOREIGN KEY (visit_id) REFERENCES Visit (unit_id),
    FOREIGN KEY (patch_id) REFERENCES Patch (unit_id)
);

CREATE TABLE SensorTractOverlap (
    sensor_id int NOT NULL,
    tract_id int NOT NULL,
    FOREIGN KEY (visit_id) REFERENCES ObservedSensor (unit_id),
    FOREIGN KEY (tract_id) REFERENCES Tract (unit_id)
);

CREATE TABLE SensorPatchOverlap (
    sensor_id int NOT NULL,
    patch_id int NOT NULL,
    FOREIGN KEY (sensor_id) REFERENCES ObservedSensor (unit_id),
    FOREIGN KEY (patch_id) REFERENCES Patch (unit_id)
);

--------------------------------------------------------------------------
-- Query for coaddition, starting from calexp
--------------------------------------------------------------------------

SELECT
    ObservedSensor.unit_id AS ObservedSensor_id,
    Visit.unit_id AS Visit_id,
    PhysicalSensor.unit_id AS PhysicalSensor_id,
    Filter.unit_id AS Filter_id,
    Camera.unit_id AS Camera_id,
    Patch.unit_id AS Patch_id,
    Tract.unit_id AS Tract_id,
    SkyMap.unit_id AS SkyMap_id,
FROM
    ObservedSensor,
    INNER JOIN Visit ON (ObservedSensor.visit_id = Visit.unit_id)
    INNER JOIN PhysicalSensor ON (ObservedSensor.physical_id = PhysicalSensor.unit_id)
    INNER JOIN Filter ON (Visit.filter_id = Filter.unit_id)
    INNER JOIN Camera ON (Visit.camera_id = Camera.unit_id)
    INNER JOIN SensorPatchOverlap ON (ObservedSensor.unit_id = SensorPatchOverlap.sensor_id)
    INNER JOIN Patch ON (SensorPatchOverlap.patch_id = Patch.unit_id)
    INNER JOIN Tract ON (Patch.tract_id = Tract.unit_id)
    INNER JOIN SkyMap ON (Tract.skymap_id = SkyMap.unit_id)
    INNER JOIN UnitDatasetJoin ON (ObservedSensor.unit_id = UnitDatasetJoin.unit_id)
    INNER JOIN DatasetType ON (UnitDatasetJoin.dataset_type_id = DatasetType.dataset_type_id)
WHERE
    DatasetType.name = "calexp"
    -- AND [any other filters on any of the given Units]
;


--------------------------------------------------------------------------
-- Query for coaddition, starting from warps
--------------------------------------------------------------------------

SELECT
    ObservedSensor.unit_id AS ObservedSensor_id,
    Visit.unit_id AS Visit_id,
    PhysicalSensor.unit_id AS PhysicalSensor_id,
    Filter.unit_id AS Filter_id,
    Camera.unit_id AS Camera_id,
    Patch.unit_id AS Patch_id,
    Tract.unit_id AS Tract_id,
    SkyMap.unit_id AS SkyMap_id,
FROM
    ObservedSensor,
    INNER JOIN Visit ON (ObservedSensor.visit_id = Visit.unit_id)
    INNER JOIN PhysicalSensor ON (ObservedSensor.physical_id = PhysicalSensor.unit_id)
    INNER JOIN Filter ON (Visit.filter_id = Filter.unit_id)
    INNER JOIN Camera ON (Visit.camera_id = Camera.unit_id)
    INNER JOIN SensorPatchOverlap ON (ObservedSensor.unit_id = SensorPatchOverlap.sensor_id)
    INNER JOIN Patch ON (SensorPatchOverlap.patch_id = Patch.unit_id)
    INNER JOIN Tract ON (Patch.tract_id = Tract.unit_id)
    INNER JOIN SkyMap ON (Tract.skymap_id = SkyMap.unit_id)
    INNER JOIN UnitDatasetJoin ON (ObservedSensor.unit_id = UnitDatasetJoin.unit_id)
    INNER JOIN DatasetType ON (UnitDatasetJoin.dataset_type_id = DatasetType.dataset_type_id)
WHERE
    DatasetType.name = "calexp"
    -- AND [any other filters on any of the given Units]
;

