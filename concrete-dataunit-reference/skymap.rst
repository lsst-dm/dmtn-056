
.. _skymap_dataunits:

SkyMap DataUnits
================

.. _SkyMap:

SkyMap
------

Each SkyMap entry represents a different way to subdivide the sky into tracts and patches, including any parameters involved in those definitions.

SkyMaps in Python are part of a polymorphic hierarchy, but unlike Cameras, their instances are not singletons, so we can't just store them in a global dictionary in the software stack.
Instead, we serialize SkyMap instances directly into the :ref:`Registry` as blobs.

Value:
    name

Dependencies:
    None


Transition
^^^^^^^^^^

Ultimately this SkyMap hierarchy should entirely replace those in the v14 SkyMap packages, and we'll store the SkyMap information directly in the Registry database rather than a separate pickle file.
There's no need for two parallel class hierarchies to represent the same concepts.

Python API
^^^^^^^^^^

.. py:class:: SkyMap

    .. py:attribute:: name

        A unique, human-readable name for the SkyMap.

        A string name for the SkyMap that can be used as its primary key in SQL.

    .. py:method:: makeTracts()

        Return the full list of :py:class:`Tract` instances associated with the Skymap.

        This virtual method will be called by a :ref:`Registry` when it adds a new :ref:`SkyMap` to populate its :ref:`Tract <sql_Tract>` and :ref:`Patch <sql_Patch>` tables.

    .. py:method:: serialize()

        Write the SkyMap to a blob.

    .. py:classmethod:: deserialize(name, blob)

        Reconstruct a SkyMap instance from a blob.

    .. todo::

        Add other methods from ``lsst.skymap.BaseSkyMap``, including iteration over Tracts.
        That may suggest removing :py:meth:`makeTracts` if it becomes redundant, or adding arguments to :py:meth:`deserialize` to provide Tracts and Patches from their tables instead of the blob.


.. _sql_SkyMap:

SQL Representation
^^^^^^^^^^^^^^^^^^

+----------------+---------+--------------+
| *SkyMap*                                |
+================+=========+==============+
| name           | varchar | PRIMARY KEY  |
+----------------+---------+--------------+
| module         | varchar | NOT NULL     |
+----------------+---------+--------------+
| serialized     | blob    | NOT NULL     |
+----------------+---------+--------------+

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

Transition
^^^^^^^^^^

Should eventually fully replace v14's ``lsst.skymap.TractInfo``.

Python API
^^^^^^^^^^

.. py:class:: Tract

    .. py:attribute:: skymap

    .. py:attribute:: number

    .. py:attribute:: region

    .. py:attribute:: patches

    .. todo::

        Add other methods from ``lsst.skymap.TractInfo``.


.. _sql_Tract:

SQL Representation
^^^^^^^^^^^^^^^^^^

+-------------+---------+----------+
| *Tract*                          |
+=============+=========+==========+
| number      | int     | NOT NULL |
+-------------+---------+----------+
| skymap_name | varchar | NOT NULL |
+-------------+---------+----------+
| region      | blob    |          |
+-------------+---------+----------+

Primary Key:
    (number, skymap_name)

Foreign Keys:
    - (skymap_name) references :ref:`SkyMap` (name)


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

Transition
^^^^^^^^^^

Should eventually fully replace v14's ``lsst.skymap.PatchInfo``.

Python API
^^^^^^^^^^

.. py:class:: Tract

    .. py:attribute:: skymap

    .. py:attribute:: tract

    .. py:attribute:: index

    .. py:attribute:: region

    .. todo::

        Add other methods from ``lsst.skymap.PatchInfo``.


.. _sql_Patch:

SQL Representation
^^^^^^^^^^^^^^^^^^

+--------------+---------+----------+
| *Patch*                           |
+==============+=========+==========+
| index        | int     | NOT NULL |
+--------------+---------+----------+
| tract_number | int     | NOT NULL |
+--------------+---------+----------+
| skymap_name  | varchar | NOT NULL |
+--------------+---------+----------+
| region       | blob    |          |
+--------------+---------+----------+


Primary Key:
    (index, tract_number, skymap_name)

Foreign Keys:
    - (skymap_name) references :ref:`SkyMap` (name)
    - (skymap_name, tract_number) references :ref:`Tract` (skymap_name, number)