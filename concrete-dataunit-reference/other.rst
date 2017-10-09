
.. _cs_calibration_dataunits:

Other DataUnits
=====================

.. _AbstractFilter:

AbstractFilter
--------------

AbstractFilters are used to label :ref:`Datasets <Dataset>` that aggregate data from multiple :ref:`Visits <Visit>` (and possibly multiple :ref:`Cameras <Camera>`.

Having two different :ref:`DataUnits <DataUnit>` for filters is necessary to make it possible to combine data from :ref:`Visits <Visit>` taken with different :ref:`PhysicalFilters <PhysicalFilter>`.

Value:
    name

Dependencies:
    None

Python API
^^^^^^^^^^

.. py:class:: AbstractFilter

    .. py:attribute:: name

        The name of the filter.

.. _sql_AbstractFilter:

SQL Representation
^^^^^^^^^^^^^^^^^^

+--------+---------+-------------+
| *AbstractFilter*               |
+========+=========+=============+
| name   | varchar | PRIMARY KEY |
+--------+---------+-------------+

