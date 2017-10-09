########
Overview
########

The data access system deals primarily with the storage, retrieval and querying of
:ref:`Datasets <Dataset>`.  An example of such a :ref:`Dataset` could be a 
calibrated exposure (``calexp``) for a particular instrument corresponding to a
particular visit and sensor, produced by a particular processing run.

These :ref:`Datasets <Dataset>` form both the input and output of units of work called
:ref:`Quanta <Quantum>`, and the data access system is also responsible for tracking the relations
between them.

The in-memory manifestation of a :ref:`Dataset` (e.g. as a Python object) is called a
:ref:`InMemoryDataset`.  The :ref:`Butler` is the user-facing interface employed to
load and store :ref:`InMemoryDatasets <InMemoryDataset>`, and query the metadata of
and relationships between :ref:`Datasets <Dataset>`.

Relations between :ref:`Datasets <Dataset>`, :ref:`Quanta <Quantum>`, and locations
for stored objects are kept in a database called a :ref:`Registry` which implements a common SQL schema.

In the database, the :ref:`Datasets <Dataset>` are grouped into :ref:`Collections <Collection>`,
which are identified by a *CollectionTag*.
Within a given :ref:`Collection` a :ref:`Dataset` is uniquely identified by a :ref:`DatasetRef`.

Conceptually a :ref:`DatasetRef` is a combination of a :ref:`DatasetType` (e.g. ``calexp``)
and a set of :ref:`DataUnits <DataUnit>`.  A :ref:`DataUnit` is a discrete unit of
data (e.g. a particular visit, tract, or filter).

A :ref:`DatasetRef` is thus a label that refers to different-but-related :ref:`Datasets <Dataset>`
in different :ref:`Collections <Collection>`. An example is a ``calexp`` for a particular visit
and CCD produced in different processing runs (with each processing run thus being a :ref:`Collection`).

A :py:class:`DatasetLabel` is a opaque, lightweight :ref:`DatasetRef` that is easier to
construct; it just holds POD values that identify :ref:`DataUnits <DataUnit>` and a :ref:`DatasetType`.

Storing the :ref:`Datasets <Dataset>` themselves, as opposed to information about them, is the
responsibility of the :ref:`Datastore`.

An overview of the framework structure can be seen in the following figure:

.. _framework_structure:

.. image:: images/concepts.png
    :scale: 75%

Users primarily interact with a particular :ref:`Butler` instance that
**provides access to a single** :ref:`Collection`.

They can use this instance to:

* Load a :ref:`Dataset` associated with a particular :py:class:`DatasetLabel`,
* Store a :ref:`Dataset` associated with a particular :py:class:`DatasetLabel`, and
* Obtain a :ref:`DataGraph`, which is a related set of :ref:`DatasetRefs <DatasetRef>` and
  :ref:`DataUnits <DataUnit>` corresponding to a (limited) SQL query.

The :ref:`Butler` implements these requests by holding a **single instance** of :ref:`Registry`
and **a single instance** of :ref:`Datastore`, to which it delegates the calls (note, however,
that this :ref:`Datastore` may delegate to one or more other :ref:`Datastores <Datastore>`).

These components constitute a separation of concerns:

* :ref:`Registry` has no knowledge of how :ref:`Datasets <Dataset>` are actually stored, and
* :ref:`Datastore` has no knowledge of how :ref:`Datasets <Dataset>` are related and their scientific meaning (i.e. knows nothing about :ref:`Collections <Collection>`, :ref:`DataUnits <DataUnit>` and :ref:`DatasetRefs <DatasetRef>`).

This separation of concerns is a key feature of the design and allows for different
implementations (or backends) to be easily swapped out, potentially even at runtime.

Communication between the components is mediated by the:

* :ref:`URI` that records **where** a :ref:`Dataset` is stored, and the
* :ref:`StorageClass` that holds information about **how** a :ref:`Dataset` can be stored.

The :ref:`Registry` is responsible for providing the :ref:`StorageClass` for
stored :ref:`Datasets <Dataset>` and the :ref:`Datastore` is responsible
for providing the :ref:`URI` from where it can be subsequently retrieved.

.. note::

    Both the :ref:`Registry` and the :ref:`Datastore` typically each
    come as a client/server pair.  In some cases the server part may be a direct backend,
    such as a SQL server or a filesystem, that does not require any custom software daemon (other than e.g. a third-party database or http server).
    In some cases, such as when server-side slicing of a :ref:`Dataset` is needed, a daemon for at least the :ref:`Datastore` will be required.
