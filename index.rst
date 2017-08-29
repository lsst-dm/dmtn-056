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

Represents a single entity of data, with associated metadata (e.g. a particular ``calexp`` for a particular instrument recorded at a particular time).


.. _DatasetType:

DatasetType
-----------

The conceptual type of which :ref:`Datasets <Dataset>` are instances (e.g. ``calexp``).


.. _ConcreteDataset:

ConcreteDataset
---------------

The in-memory manifestation of a :ref:`Dataset` (e.g. an ``afw::image::Exposure`` with the contents of a particular ``calexp``).


.. _DataRef:

DataRef
-------

Unique identifier of a :ref:`Dataset` within a :ref:`Repository`.


.. _Repository:

Repository
----------

An entity that one can point a butler to that has the following three properties:

- Has at most one :ref:`Dataset` per :ref:`DataRef`.
- Has a label that humans can parse (i.e. :ref:`RepositoryRef`)
- Provides enough info to a make globally (accross repositories) unique filename (or key for an object store) given a :ref:`DataRef`.


.. _RepositoryRef:

RepositoryRef
-------------

Globally unique, human parseable, identifier of a :ref:`Repository` (e.g. the path to it or a URI).


.. _Unit:

Unit
----

Unique (primary) key within a repository, the set of which (one for every table) forms a full unique :ref:`DataRef`.


.. _StorageButler:

StorageButler
-------------

Abstract interface that has two methods:

- ``get(DataRef dr) -> ConcreteDataset``
- ``put(DataRef dr, ConcreteDataset obj) -> None``

where :ref:`ConcreteDataset` is any kind of in-memory object supported by the butler.

The input and output :ref:`ConcreteDataset` are always bitwise identical. Transformations are to be handled by higher level wrappers (that may expose the same interface).

Backend storage is not defined by this interface. Different :ref:`StorageButler` implementations may write to single/multiple (FITS/HDF5) files, (no)sql-databases, object stores, etc. They may even delegate part of the work to other concrete :ref:`StorageButlers <StorageButler>`.


.. _DataRefExpression:

DataRefExpression
-----------------

Is an expression (SQL query against a fixed schema) that can be evaluated by an :ref:`AssociationButler` to yield one or more unique :ref:`DataRefs <DataRef>` and their relations (in a :ref:`RepositoryGraph`).

An open question is if it is sufficient to only allow users to vary the ``WHERE`` clause of the SQL query, or if custom joins are also required.


.. _RepositoryGraph:

RepositoryGraph
---------------

A graph in which the nodes are :ref:`DataRefs <DataRef>` and :ref:`Units <Unit>`, and the edges are the relations between them.


.. _AssociationButler:

AssociationButler
-----------------

Has one method:

- ``evaluateExpression(List<DatasetTypes> types, DataRefExpression expression) -> RepositoryGraph``

Presents the user with a fixed schema (set of tables) that the :ref:`DataRefExpression` can be evaluated against to yied a graph of unique :ref:`DataRefs <DataRef>` with their relations (this is typically a subset of the full repository graph).

In different implementations these tables may exist directly, as a pass-through to a ``SQLite``/``PostgreSQL``/``MySQL`` database that actually has them, or it may have to do some kind of mapping.

The point is that users/developers can write their SQL queries against this fixed schema.


.. _ConvenienceButler:

ConvenienceButler
-----------------

Wraps an :ref:`AssociationButler` with some tooling to build up a :ref:`DataRefExpression`. This may be a simple mini-language parser (e.g. for globs) or even some interactive tool.


.. .. rubric:: References

.. Make in-text citations with: :cite:`bibkey`.

.. .. bibliography:: local.bib lsstbib/books.bib lsstbib/lsst.bib lsstbib/lsst-dm.bib lsstbib/refs.bib lsstbib/refs_ads.bib
..    :encoding: latex+latin
..    :style: lsst_aa
