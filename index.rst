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

In the :ref:`Common Schema <CommonSchema>`, a :ref:`DataUnit` is a row in the table for its :ref:`DataUnitType`.  :ref:`DataUnits <DataUnit>` must be shared across different repositories (which may be backed by different database systems), so their primary keys in the :ref:`Common Schema` must not be database-specific quantities such as autoincrement fields.


.. _DataUnitType:

DataUnitType
------------

The conceptual type of a :ref:`DataUnit` (such as visit, tract, or filter).

In the :ref:`Common Schema <CommonSchema>`, each :ref:`DataUnitType` is a table that the holds :ref:`DataUnits <DataUnit>` of that type as its rows.


.. _DatasetRef:

DatasetRef
----------

A unique identifier for a :ref:`Dataset` across :ref:`Repositories <Repository>`.  A :ref:`DatasetRef` is conceptually just combination of a :ref:`DatasetType` and a tuple of :ref:`DataUnits <DataUnit>`.

In the :ref:`Common Schema <CommonSchema>`, a :ref:`DatasetRef` is a row in the table for its :ref:`DatasetType`, with a foreign key field pointing to a :ref:`DataUnit` row for each element in tuple of :ref:`DataUnits <DataUnit>`.


.. _Repository:

Repository
----------

An entity that one can point a butler to that has the following three properties:

- Has at most one :ref:`Dataset` per :ref:`DatasetRef`.
- Has a label that humans can parse (i.e. :ref:`RepositoryRef`)
- Provides enough info to a make globally (across repositories) unique filename (or key for an object store) given a :ref:`DatasetRef`.


.. _RepositoryRef:

RepositoryRef
-------------

Globally unique, human parseable, identifier of a :ref:`Repository` (e.g. the path to it or a URI).


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

In practice delegates the actual IO to a lower level butler which may be another :ref:`StorageButler` or a :ref:`PrimitiveButler` (in which case it will map the :ref:`DatasetRef` to a :ref:`Key`).


.. _AssociationButler:

AssociationButler
-----------------

Has one method:

- ``evaluateExpression(List<DatasetTypes> types, DatasetExpression expression) -> DataGraph``

Presents the user with the :ref:`Common Schema` (a set of tables) that the :ref:`DatasetExpression` can be evaluated against to yied a graph of unique :ref:`DatasetRefs <DatasetRef>` with their relations (this is typically a subset of the full repository graph).

In different implementations these tables may exist directly, as a pass-through to a ``SQLite``/``PostgreSQL``/``MySQL`` database that actually has them, or it may have to do some kind of mapping.

The point is that users/developers can write their SQL queries against this fixed schema.


.. _ConvenienceButler:

ConvenienceButler
-----------------

Wraps an :ref:`AssociationButler` with some tooling to build up a :ref:`DatasetExpression`. This may be a simple mini-language parser (e.g. for globs) or even some interactive tool.


.. _CommonSchema:

Common Schema
=============


.. .. rubric:: References

.. Make in-text citations with: :cite:`bibkey`.

.. .. bibliography:: local.bib lsstbib/books.bib lsstbib/lsst.bib lsstbib/lsst-dm.bib lsstbib/refs.bib lsstbib/refs_ads.bib
..    :encoding: latex+latin
..    :style: lsst_aa
