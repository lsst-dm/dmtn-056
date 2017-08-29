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

.. sectnum::

.. Add content below. Do not include the document title.

.. note::

   **This technote is not yet published.**

   For now, a WIP scratch pad for new Butler APIs.



Purpose
=======

This document describes a possible abstract design for the buter to facilitate discussions. It does not map directly to actual code, but rather serves to clarify our thinking on the concepts.


Components
==========

Dataset
-------

Represents a single entity of data, with associated metadata (e.g. a particular `calexp` for a particular instrument recorded at a particular time).


DatasetType
-----------

The conceptual type of which Datasets are instances (e.g. `calexp`).


ConcreteDataset
---------------

The in-memory manifestation of a Dataset (e.g. an `afw::image::Exposure` with the contents of a particular `calexp`).


DataRef
-------

Unique identifier of a Dataset within a Repository (see below).


Repository
----------

An entity that one can point a butler to that has the following three properties:

- Has at most one Dataset per DataRef
- Has a label that humans can parse (i.e. RepositoryRef)
- Provides enough info to a make globally (accross repositories) unique `filename` (or key for an object store) given a DataRef.


RepositoryRef
-------------

Globally unique, human parseable, identifier of a Repository (e.g. the path to it or a URI).


Unit
----

Unique (primary) key within a repository, the set of which (one for every table) forms a full unique DataRef.


StorageButler
-------------

Abstract interface that has two methods:

- ``get(DataRef dr) -> ConcreteDataset``
- ``put(DataRef dr, ConcreteDataset obj) -> None``

where ConcreteDataset is any kind of in-memory object supported by the butler.

The input and output ConcreteDataset are always bitwise identical. Transformations are to be handled by higher level wrappers (that may expose the same interface).

Backend storage is not defined by this interface. Different StorageButler implementations may write to single/multiple (FITS/HDF5) files, (no)sql-databases, object stores, etc. They may even delegate part of the work to other concrete StorageButlers.


DataRefExpression
-----------------

Is an expression (SQL query against a fixed schema) that can be evaluated by an AssociationButler to yield one or more unique DataRefs and their relations (in a RepositoryGraph).

An open question is if it is sufficient to only allow users to vary the `WHERE` clause of the SQL query, or if custom joins are also required.


RepositoryGraph
---------------

A graph in which the nodes are DataRefs and Units, and the edges are the relations between them.


AssociationButler
-----------------

Has one method:

- ``evaluateExpression(DataRefExpression expression) -> RepositoryGraph``

Presents the user with a fixed schema (set of tables) that the DataRefExpression can be evaluated against to yied a graph of unique DataRef's with their relations (this is typically a subset of the full repository graph).

In different implementations these tables may exist directly, as a pass-through to a `sqllite`/`postgreSQL`/`MySQL` database that actually has them, or it may have to do some kind of mapping.

The point is that users/developers can write their SQL queries against this fixed schema.

ConvenienceButler
-----------------

Wraps an AssociationButler with some tooling to build up a DataRefExpression. This may be a simple mini-language parser (e.g. for globs) or even some interactive tool.


.. .. rubric:: References

.. Make in-text citations with: :cite:`bibkey`.

.. .. bibliography:: local.bib lsstbib/books.bib lsstbib/lsst.bib lsstbib/lsst-dm.bib lsstbib/refs.bib lsstbib/refs_ads.bib
..    :encoding: latex+latin
..    :style: lsst_aa
