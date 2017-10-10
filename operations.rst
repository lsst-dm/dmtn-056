##########
Operations
##########

.. _basic_io:

Basic I/O
=========

To see how the various components interact we first examine a basic ``get`` and ``put`` operations for the basic case of a non-composite :ref:`Dataset`.
We assume that the :ref:`Butler` is configured with an external :ref:`Registry` and :ref:`Datastore`, both consisting of a client-server pair.

Basic ``get``
-------------

The user has a :py:class:`DatasetLabel`, constructed or obtained by a query and wishes to retrieve the associated :ref:`InMemoryDataset`.

This proceeds allong the following steps:

1. User calls: ``butler.get(label)``.
2. :ref:`Butler` forwards this call to its :ref:`Registry`, adding the :ref:`CollectionTag <Collection>` it was configured with (i.e. ``butler.registry.find(butler.config.inputCollection, label)``).
3. :ref:`Registry` performs the lookup on the server using SQL and returns the :ref:`URI` for the stored :ref:`Dataset` (via a :py:class:`DatasetHandle`)
4. :ref:`Butler` forwards the request, with both the :ref:`URI` and the :ref:`StorageClass`, to the :ref:`Datastore` client (i.e. ``butler.datastore.get(handle.uri, handle.type.storageClass)``).
5. :ref:`Datastore` client requests a serialized version of the :ref:`Dataset` from the server using the :ref:`URI`.
6. Using the :ref:`StorageClass` to determine the appropriate deserialization function, the :ref:`Datastore` client then materializes the :ref:`InMemoryDataset` and returns it to the :ref:`Butler`.
7. :ref:`Butler` then returns the :ref:`InMemoryDataset` to the user.

See :py:meth:`the API documentation <Butler.get>` for more information.

.. note::

    The :ref:`Datastore` request can be a simple ``HTTP GET`` request for a stored FITS file, or something more complicated.
    In the former case the materialization would be a simple FITS read (e.g. of a ``calexp``), with the reader determined by the :ref:`StorageClass` retrieved from the :ref:`Registry`.

.. note::

    The serialized version sent over the wire doesn't have to correspond to the format stored on disk in the :ref:`Datastore` server.  It just needs to be serialized in the form expected by the client.

Basic ``put``
-------------

The user has a :ref:`InMemoryDataset` and wishes to store this at a particular :py:class:`DatasetLabel`.

This proceeds allong the following steps:

1. User calls: ``butler.put(label, inMemoryDataset)``.
2. :ref:`Butler` expands the :py:class:`DatasetLabel` into a full :py:class:`DatasetRef` using the :ref:`Registry`, by calling ``datasetRef = butler.registry.getStorageClass(butler.config.outputCollection, datasetRef)``.
3. :ref:`Butler` obtains a :ref:`Path` by calling ``path = datasetRef.makePath(butler.config.outputCollection, template)``. This path is a hint to be used by the :ref:`Datastore` to decide where to store it.  The template is provided by the :ref:`Registry` but may be overridden by the :ref:`Butler`.
4. :ref:`Butler` then asks the :ref:`Datastore` client to store the file by calling: ``butler.datastore.put(inMemoryDataset, datasetRef.type.storageClass, path)``.
5. The :ref:`Datastore` client then uses the serialization function associated with the :ref:`StorageClass` to serialize the :ref:`InMemoryDataset` and sends it to the :ref:`Datastore` server.
   Depending on the type of server it may get back the actual :ref:`URI` or the client can generate it itself.
6. :ref:`Datastore` returns the actual :ref:`URI` to the :ref:`Butler`.
7. :ref:`Butler` calls the :ref:`Registry` function ``addDataset`` to add the :ref:`Dataset` to the collection.
8. :ref:`Butler` returns a :py:class:`DatasetHandle` to the user.

See :py:class:`the API documentation <Butler.put>` for more information.

.. _composites:

Composites
==========

A :ref:`Dataset` can be **composite**, in which case it consists of a **parent** :ref:`Dataset` and one or more child :ref:`Datasets <Dataset>`.  An example would be an ``Exposure`` which consists of a ``Wcs`` a ``Mask`` and an ``Image``.  There are several ways this may be stored by the :ref:`Datastore`:

* As part of the parent :ref:`Dataset` (e.g. the full ``Exposure`` is written to a single FITS file).
* As a set of entities without a parent (e.g. only the ``Wcs``, ``Mask`` and ``Image`` are written separately and the ``Exposure`` needs to be composed from them).
* As a mix of the two extremes (e.g. the ``Mask`` and ``Image`` are part of the ``Exposure`` file but the ``Wcs`` is written to a separate file).

In either case the user expects to be able to read an individual component, and in case the components are stored separately the transfer should be efficient.

In addition, it is desirable to **override** parts of a composite :ref:`Dataset` (e.g. updated metadata).

To support this the :ref:`Registry` is also responsible for storing the component :ref:`Datasets <Dataset>` of the **composite**.

The :py:class:`DatasetHandle` returned by :py:meth:`Registry.find` therefore not only includes the :ref:`URI` and :ref:`StorageClass` of the **parent** (associated with the :ref:`DatasetRef`), but also a ``components`` dictionary of ``name : DatasetHandle`` specifying its **children**.

The :ref:`Butler` retrieves **all** :ref:`Datasets <Dataset>` from the :ref:`Datastore` as :ref:`InMemoryDatasets <InMemoryDataset>` and then calls the ``assemble`` function associated with the :ref:`StorageClass` of the primary to create the final composed :ref:`InMemoryDataset`.

This process is most easily understood by reading the API documentation for :py:meth:`butler.get <Butler.get>` and :py:meth:`butler.put <Butler.put>`.


Transferring Registries and Datastores
======================================

.. todo::

    Fill this in: make a new Registry with new URIs from a subset, transfer Datasets into a new Datastore explicitly.


Remote Access and Caching
=========================

The user has a :ref:`Butler` instance. This :ref:`Butler` instance holds a local :ref:`Registry` client instance, that is connected to a remote **read-only** :ref:`Registry` server (database). It also holds a local :ref:`Datastore` client that also is connected to a remote :ref:`Datastore`.

The user now calls ``butler.get()`` to obtain an :ref:`InMemoryDataset` from the :ref:`Datastore`. Then does some further processing, and subsequently wants to load the **same** :ref:`InMemoryDataset` again.

This is most easily supported by through a **caching** :ref:`Datastore`. The :ref:`Butler` now holds an instance of the caching :ref:`Datastore` instead. And the caching :ref:`Datastore` in turn holds the client to the remote :ref:`Datastore`.

.. digraph:: ButlerWithDatastoreCache
    :align: center

    node[shape=record]
    edge[dir=back, arrowtail=empty]

    Butler -> ButlerConfiguration [arrowtail=odiamond];
    Butler -> DatastoreCache [arrowtail=odiamond];
    DatastoreCache -> Datastore [arrowtail=odiamond];
    Butler -> Registry [arrowtail=odiamond];

An trivial implementation, for a non-persistent cache, could be:

.. py:class:: DatastoreCache

    .. py:attribute:: cache

        A dictionary of ``{(URI, parameters) : InMemoryDataset}``.

    .. py:attribute:: datastore

        The chained :ref:`Datastore`.

    .. py:method:: __init__(datastore)

        Initialize with chained :ref:`Datastore`.

    .. py:method:: get(uri, parameters=None)

        Implemented as:

        .. code:: python

            def get(uri, parameters=None):
                if (uri, parameters) not in self.cache:
                    self.cache[(uri, parameters)] = self.datastore.get(uri, parameters)

                return self.cache[(uri, parameters)]

    .. py:method:: put(inMemoryDataset, storageClass, path, typeName=None) -> URI, {name: URI}

        Direct forward to ``self.datastore.put``.

    .. py:method:: transfer(inputDatastore, inputUri, storageClass, path, typeName=None) -> URI, {name: URI}

        Direct forward to ``self.datastore.transfer`` (probably).

.. todo::

    * What to when ``parameters`` differ? Should we re-slice?
    * What about ``transfer``?

SuperTask Pre-Flight and Execution
==================================

.. note::

    This description currently has the SuperTask *control code* operating directly on :ref:`Registry` and :ref:`Datastore` objects instead of :ref:`Butlers <Butler>`.
    Actual SuperTasks, of course, still only see a :ref:`Butler`.
    But we should decide when the design is more mature whether to hide the interfaces the control code uses behind :ref:`Butler` as well.

Preflight
---------

SuperTask Preflight begins with an activator

.. todo::

    Fill this in.  May want to try a few examples, covering applying master calibrations and making coadds.

Direct Execution
----------------

.. todo::

    Fill this in.  Run directly against a full Registry and Datastore.

Staged Execution
----------------

.. todo::

    Fill this in.  Run directly against a limited Registry and local Datastore that are proxies for the full ones.  Show how to do the transfers through our interfaces *and* how to get the necessary information to do them externally.


DataUnit Updates and Inserts
============================

.. todo::

    Fill these sections in.  Make sure to handle :ref:`dataunit_joins`.

Raw Data Ingest
---------------

Making Master Calibrations
--------------------------

Defining SkyMaps
----------------

