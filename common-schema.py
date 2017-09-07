from datetime import datetime


class Field(object):
    """A descriptor for DataUnit classes that represents a POD attribute that
    can usually be mapped directly to a field in a database table.

    Parameters
    ----------
    dtype : `type`
        A Python type object indicating the field type.  Allowed values include
        `int`, `str`, `float`, and `datetime`.
    optional : `bool`
        If True, the field's value may be None.
    """

    def __init__(self, dtype, optional=False):
        pass

    def __get__(self, obj, type=None):
        pass


class Link(Field):
    """A descriptor for DataUnit and DatasetTemplate classes that represents a
    relationship to a (different) DataUnit.

    Links map roughly to foreign key fields in database tables, but may be
    implemented via a join on multiple fields rather than just one.

    Parameters
    ----------
    dtype : `type`
        The DataUnit subclass whose instances will be held by this attribute.
    optional : `bool`
        If True, the field's value may be None.
    reverse : `ReverseLinkDict`
        An attribute on `dtype` that should contain back-references; a dict
        whose values are instances of the type to which the Link is attached
        and whose keys are their __meta__['label'] field values.  Must be
        None when the Link is attached to a DatasetTemplate; datasets are
        always back-linked to the DataUnits they are defined on via a different
        mechanism.
    key : `tuple`
        A tuple of Field or (usually) Link instances on the same class that
        holds this Link, whose elements correspond to the elements of
        `dtype.__meta__['key']` and indicate how to build a tuple that uniquely
        identifies an instance of `dtype`.  None is used to indicate a value
        that cannot be obtained from a different Link or Field and hence must
        be held by the current one; usually this is the element that
        corresponds to `dtype.__meta__['label']`.
    """

    def __init__(self, dtype, optional=False, reverse=None, key=(None,)):
        pass

    def __get__(self, obj, type=None):
        pass


class ReverseLinkDict(object):
    """A descriptor for DataUnit and DatasetTemplate classes that represents
    a dictionary-like object with back-references defined by a Link.

    ReverseLinkDicts are always default constructed, with their behavior
    fully defined by the definition of a Link in another class with the
    ReverseLinkDict's holder as the Link's dtype.

    The values in the dict are the instances of the DataUnit that holds
    the corresponding Link, and the keys are their __meta__['label'] fields
    values.

    ReverseLinkDicts may not hold DatasetTemplate instances (so Links on
    DatasetTemplates must be defined with `reverse=None`, the default).
    """

    def __init__(self):
        pass

    def __get__(self, obj, type=None):
        pass


class DataUnit(object):
    """A unit of data, independent of any actual data product.

    DataUnit is an abstract base class whose subclasses define discrete units
    of data that can be combined (via DatasetIdentifier) to define the
    identifier for a dataset type.  Only direct subclasses should exist (i.e.
    the inheritance hierarchy should only be one level deep).

    All DataUnit subclasses should have a __meta__ class attribute, which is a
    dict with the following entries:

    'label' (optional)
        A Field instance attached to the subclass that serves as the most
        important identifier for the unit.  This will be used in
        `ReverseLinkDict` attributes as the key type and allows the name of
        this attribute to be left out in expressions (for example, if
        ``Visit.__meta__["label"] = Visit.number``, then "Visit = 56" may
        be used in expressions instead of  "Visit.number = 56".

    'key' (required)
        A tuple of Field and Link instances attached to the subclass whose
        values together uniquely identify an instance of the DataUnit, and
        can hence be used for equality comparison and dictionary/database
        lookups.  One element in the tuple (by convention, the last) should
        be the 'label' Field, and generally the others are all Links.
    """
    pass


class DatasetIdentifier(object):
    pass


class DatasetQueryDict(object):
    pass


class SkyRegion(object):

    def overlaps(self, other):
        raise NotImplementedError()


class SkyMapOverlapList(object):
    """A descriptor that returns a nested sequence containing the Patches that
    overlap a SkyRegion, grouped by Tract.

    Each element in the returned sequnce is a two-element tuple containing a
    Tract instance and a set of Patch instances.  Typical iteration pattern is:

        for tract, patches in overlaps:
            for patch in patches:
                yield patch

    where `tract` is a Tract instance, and `patch` is a Patch instance.

    The `.tracts` and `.patches` attributes can be used to obtain flattened
    sets containing only the Tract or Patch instances, respectively.
    """
    pass


class ObservationOverlapList(object):
    """A descriptor that returns a nested sequence containing the
    ObservedSensors that overlap a SkyRegion, grouped by Visit.

    Each element in the returned sequnce is a two-element tuple containing a
    Visit instance and a set of ObservedSensor instances.  Typical iteration
    pattern is:

        for visit, sensors in overlaps:
            for sensor in sensors:
                yield sensor

    where `visit` is a Visit instance, and `sensor` is an ObservedSensor
    instance.

    The `.visits` and `.sensors` attributes can be used to obtain flattened
    sets containing only the Visit or ObservedSensor instances, respectively.
    """
    pass


class Camera(DataUnit):
    name = Field(str)

    __meta__ = {
        "label": name,
        "key": (name,)
    }


class Filter(DataUnit):
    camera = Link(Camera, optional=True)
    name = Field(str)

    __meta__ = {
        "label": name,
        "key": (camera, name)
    }


class PhysicalSensor(DataUnit):
    camera = Link(Camera)
    name = Field(str)        # Camera-dependent: "R12S21" for LSST, "46" for HSC?
    purpose = Field(str)     # e.g. SCIENCE, WAVEFRONT, GUIDE
    group = Field(str)       # Camera-dependent: rafts for LSST, rotation groups for HSC?

    __meta__ = {
        "label": name,
        "key": (camera, name)
    }


class CalibRange(DatasetIdentifier):
    camera = Link(Camera)
    filter = Link(Filter, optional=True, key=(camera, None))
    first_visit = Field(int)
    last_visit = Field(int)


class SensorCalibRange(DatasetIdentifier):
    camera = Link(Camera)
    sensor = Link(PhysicalSensor, key=(camera, None))
    filter = Link(Filter, optional=True, key=(camera, None))
    first_visit = Field(int)
    last_visit = Field(int)


class Visit(DataUnit, DatasetIdentifier):
    camera = Link(Camera)
    number = Field(int)
    begin = Field(datetime)
    end = Field(datetime)
    filter = Link(Filter, key=(camera, None))
    region = Link(SkyRegion)

    sensors = ReverseLinkDict()  # dict of {ObservedSensor.sensor: ObservedSensor}
    snaps = ReverseLinkDict()    # dict of {Snap.number: Snap}

    overlapping = SkyMapOverlapList()  # list of tuples of (Tract, [Patches])

    calibs = DatasetQueryDict(
        CalibRange,
        equal=[(camera, CalibRange.camera), (filter, CalibRange.filter)],
        between=[(number, CalibRange.first_visit, CalibRange.last_visit)]
    )

    __meta__ = {
        "label": number,
        "key": (camera, number)
    }


class Snap(DataUnit, DatasetIdentifier):
    camera = Link(Camera)
    visit = Link(Visit, reverse=Visit.snaps, key=(camera, None))
    number = Field(int)
    begin = Field(datetime)
    end = Field(datetime)

    __meta__ = {
        "label": number,
        "key": (camera, visit, number)
    }


class ObservedSensor(DataUnit, DatasetIdentifier):
    camera = Link(Camera)
    sensor = Link(PhysicalSensor, key=(camera, None))
    visit = Link(Visit, reverse=Visit.sensors, key=(camera, None))
    region = Link(SkyRegion)

    overlapping = SkyMapOverlapList()

    calibs = DatasetQueryDict(
        CalibRange,
        links=[visit,],
        equal=[(camera, CalibRange.camera),
               (sensor, CalibRange.sensor),
               (Visit.filter, CalibRange.filter)],
        between=[(Visit.number, CalibRange.first_visit, CalibRange.last_visit)]
    )

    __meta__ = {
        "key": (camera, sensor, visit)
    }


class SkyMap(DataUnit):
    name = Field(str)

    __meta__ = {
        "label": name,
        "key": (name, )
    }


class Tract(DataUnit, DatasetIdentifier):
    skymap = Link(SkyMap)
    number = Field(int)
    region = Field(SkyRegion)

    patches = ReverseLinkDict()  # dict of {Patch.patch: Patch}
    overlapping = ObservationOverlapList()

    __meta__ = {
        "label": number,
        "key": (skymap, number)
    }


class Patch(DataUnit, DatasetIdentifier):
    skymap = Link(SkyMap)
    tract = Link(Tract, key=(skymap, None), reverse=Tract.patches)
    index = Field(int)
    region = Link(SkyRegion)

    overlapping = ObservationOverlapList()

    __meta__ = {
        "label": index,
        "key": (skymap, tract, index)
    }


class Raw(DatasetIdentifier):
    camera = Link(Camera)
    visit = Link(Visit, key=(camera, None))
    snap = Link(Snap, key=(camera, visit, None))
    sensor = Link(ObservedSensor, key=(camera, None, visit))


class JointCalVisit(DatasetIdentifier):
    skymap = Link(SkyMap)
    tract = Link(Tract)
    camera = Link(Camera)
    visit = Link(Visit)


class JointCalSensor(DatasetIdentifier):
    skymap = Link(SkyMap)
    tract = Link(Tract)
    camera = Link(Camera)
    visit = Link(Visit)
    sensor = Link(ObservedSensor, key=(camera, None, visit))


class Warp(DatasetIdentifier):
    skymap = Link(SkyMap)
    tract = Link(Tract)
    patch = Link(Patch)
    camera = Link(Camera)
    visit = Link(Visit)


class Coadd(DatasetIdentifier):
    skymap = Link(SkyMap)
    tract = Link(Tract)
    patch = Link(Patch)
    filter = Link(Filter, optional=True)
