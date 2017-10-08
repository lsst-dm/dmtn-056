
.. _cs_skymap_dataunits:

SkyMap DataUnits
================

.. _cs_table_SkyMap:

+-----------+---------+------------------+
| *SkyMap*                               |
+===========+=========+==================+
| skymap_id | int     | PRIMARY KEY      |
+-----------+---------+------------------+
| name      | varchar | NOT NULL, UNIQUE |
+-----------+---------+------------------+

Each :ref:`SkyMap <cs_table_Skymap>` entry represents a different way to subdivide the sky into tracts
and patches, including any parameters involved in those defitions (i.e.
different configurations of the same ``lsst.skymap.BaseSkyMap`` subclass yield
different rows).

.. todo::

    While SkyMaps need unique, human-readable names, it may also
    be wise to add a hash or pickle of the SkyMap instance that defines the
    mapping to avoid duplicate entries (not yet included).

.. _cs_table_Tract:

+-----------+------+-----------------------------------------+
| *Tract*                                                    |
+===========+======+=========================================+
| tract_id  | int  | PRIMARY KEY                             |
+-----------+------+-----------------------------------------+
| number    | int  | NOT NULL                                |
+-----------+------+-----------------------------------------+
| skymap_id | int  | NOT NULL, REFERENCES SkyMap (skymap_id) |
+-----------+------+-----------------------------------------+
| region    | blob |                                         |
+-----------+------+-----------------------------------------+
| CONSTRAINT UNIQUE (skymap_id, num)                         |
+-----------+------+-----------------------------------------+

A :ref:`Tract <cs_table_Tract>` is a contiguous, simple area on the sky with a 2-d Euclidian
coordinate system defined by a single map projection.

.. todo::

    If the parameters of the sky projection and the Tract's various bounding boxes
    can be standardized across all SkyMap implementations, it may be useful to
    include them in the table as well.

.. _cs_table_Patch:

+----------+------+--------+------------------------------+
| *Patch*                                                 |
+==========+======+========+==============================+
| patch_id | int  | PRIMARY KEY                           |
+----------+------+--------+------------------------------+
| tract_id | int  | NOT NULL, REFERENCES Tract (tract_id) |
+----------+------+--------+------------------------------+
| index    | int  | NOT NULL                              |
+----------+------+--------+------------------------------+
| region   | blob |                                       |
+----------+------+--------+------------------------------+
| CONSTRAINT UNIQUE (tract_id, index)                     |
+----------+------+--------+------------------------------+

:ref:`Tracts <cs_table_Tract>` are subdivided into :ref:`Patches <cs_table_Patch>`,
which share the Tract coordinate system and define similarly-sized regions that
overlap by a configurable amount.  As with Tracts, we may want to include fields
to describe Patch boundaries in this table in the future.
