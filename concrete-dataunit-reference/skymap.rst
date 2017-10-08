
.. _skymap_dataunits:

SkyMap DataUnits
================

.. _SkyMap:

SkyMap
------

Each SkyMap entry represents a different way to subdivide the sky into tracts and patches, including any parameters involved in those defitions (i.e. different configurations of the same ``lsst.skymap.BaseSkyMap`` subclass yield different rows).

.. todo::

    While SkyMaps need unique, human-readable names, it may also be wise to add a hash or pickle of the SkyMap instance that defines the mapping to avoid duplicate entries (not yet included).

Value:
    name

Dependencies:
    None

Python API
^^^^^^^^^^

.. _sql_SkyMap:

SQL Representation
^^^^^^^^^^^^^^^^^^

+-----------+---------+------------------+
| *SkyMap*                               |
+===========+=========+==================+
| skymap_id | int     | PRIMARY KEY      |
+-----------+---------+------------------+
| name      | varchar | NOT NULL, UNIQUE |
+-----------+---------+------------------+

.. _Tract:

Tract
-----

A Tract is a contiguous, simple area on the sky with a 2-d Euclidian coordinate system related to spherical coordinates by a single map projection.

.. todo::

    If the parameters of the sky projection and/or the Tract's various bounding boxes can be standardized across all SkyMap implementations, it may be useful to include them in the table as well.

Value:
    number

Dependencies:
    :ref:`SkyMap`

Python API
^^^^^^^^^^

.. _sql_Tract:

SQL Representation
^^^^^^^^^^^^^^^^^^

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

.. _Patch:

Patch
-----

:ref:`Tracts <Tract>` are subdivided into Patches, which share the :ref:`Tract` coordinate system and define similarly-sized regions that overlap by a configurable amount.

.. todo::

    As with Tracts, we may want to include fields to describe Patch boundaries in this table in the future.

Value:
    index

Dependencies:
    :ref:`Tract`

Python API
^^^^^^^^^^

.. _sql_Patch:

SQL Representation
^^^^^^^^^^^^^^^^^^

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

