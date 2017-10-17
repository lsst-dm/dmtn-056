
.. _Butler:

Butler
======

A high level object that provides read access to the :ref:`Datasets <Dataset>` in a single :ref:`Collection` and write access to a single :ref:`Run`.

Butler is a concrete, final Python class in the current design; all extensibility is provided by the :ref:`Registry` and :ref:`Datastore` instances it holds.

.. digraph:: Butler
    :align: center

    node[shape=record]
    edge[dir=back, arrowtail=empty]

    Butler [label="{Butler|+ config\n + datastore\n+ registry|+ get()\n + put()}"];

    Butler -> ButlerConfiguration [arrowtail=odiamond];
    Butler -> Datastore [arrowtail=odiamond];
    Butler -> Registry [arrowtail=odiamond];


Transition
^^^^^^^^^^

The new Butler plays essentially the same role as the v14 Butler.

Python API
^^^^^^^^^^

.. py:class:: Butler

    .. py:attribute:: config

        a :py:class:`ButlerConfiguration` instance

    .. py:attribute:: datastore

        a :py:class:`Datastore` instance

    .. py:attribute:: registry

        a :py:class:`Registry` instance

    .. py:method:: get(label, parameters=None)

        Load a :ref:`Dataset` or a slice thereof from the Butler's :ref:`Collection`.

        :param DatasetLabel label: a :py:class:`DatasetLabel` that identifies the :ref:`Dataset` to retrieve.

        :param dict parameters: a dictionary of :ref:`StorageClass`-specific parameters that can be used to obtain a slice of the :ref:`Dataset`.

        :returns: an :ref:`InMemoryDataset`.

        Implemented as:

        .. code:: python

            handle = self.registry.find(self.config.collection, label)
            return self.getDirect(handle, parameters)

        .. todo::

            * Implementation requires all components to be able to handle (typically pass-through)
              parameters passed for the composite.  Could we instead get away with only passing those
              when getting the parent from the :ref:`Datastore`?

            * Recursive composites were broken by a minor update.
              Would probably not be hard to add back in if we decide we need them, but they'd make the logic a bit harder to follow so not worth doing now.

    .. py:method:: getDirect(handle, parameters=None)

        Load a :ref:`Dataset` or a slice thereof from a :py:class:`DatasetHandle`.

        Unless :py:meth:`Butler.get`, this method allows :ref:`Datasets <Dataset>` outside the Butler's :ref:`Collection` to be read as long as the :py:class:`DatasetHandle` that identifies them can be obtained separately.
        This is needed to support the :ref:`Comparison SuperTasks <running_comparison_supertasks>` use case.

        :param DatasetHandle handle: a pointer to the :ref:`Dataset` to load.

        :param dict parameters: a dictionary of :ref:`StorageClass`-specific parameters that can be used to obtain a slice of the :ref:`Dataset`.

        :returns: an :ref:`InMemoryDataset`.

        Implemented as:

        .. code:: python

            parent = self.datastore.get(handle.uri, handle.type.storageClass, parameters) if handle.uri else None
            children = {name : self.datastore.get(childHandle, parameters) for name, childHandle in handle.components.items()}
            return handle.type.storageClass.assemble(parent, children)

    .. py:method:: put(label, dataset, producer=None)

        Write a :ref:`Dataset`.

        :param DatasetLabel label: a :py:class:`DatasetLabel` that will identify the :ref:`Dataset` being stored.

        :param dataset: the :ref:`InMemoryDataset` to store.

        :param Quantum producer: the :ref:`Quantum` instance that produced the :ref:`Dataset`.  May be ``None`` for some :ref:`Registries <Registry>`.  ``producer.run`` must match ``self.config.run``.

        :returns: a :py:class:`DatasetHandle`

        Implemented as:

        .. code:: python

            ref = self.registry.expand(label)
            run = self.config.run
            assert(producer is None or run == producer.run)
            template = self.config.templates.get(ref.type.name, None)
            path = ref.makePath(run, template)
            uri, components = self.datastore.put(inMemoryDataset, ref.type.storageClass, path, ref.type.name)
            return self.registry.addDataset(ref, uri, components, producer=producer, run=run)

    .. py:method:: markInputUsed(quantum, ref)

        Mark a :ref:`Dataset` as having been "actually" (not just predicted-to-be) used by a :ref:`Quantum`.

        :param Quantum quantum: the dependent :ref:`Quantum`.

        :param DatasetRef ref: the :ref:`Dataset` that is a true dependency of ``quantum``.

        Implemented as:

        .. code:: python

            handle = self.registry.find(self.config.collection, ref)
            self.registry.markInputUsed(handle, quantum)

    .. py:method:: unlink(*labels)

        Remove the :ref:`Datasets <Dataset>` associated with the given :py:class:`DatasetLabels <DatasetLabel>` from the Butler's :ref:`Collection`, and signal that they may be deleted from storage if they are not referenced by any other :ref:`Collection`.

        Implemented as:

        .. code:: python

            handles = [self.registry.find(self.config.collection, labels)
                       for label in labels]
            for handle in self.registry.disassociate(self.config.collection, handles, remove=True):
                self.datastore.remove(handle.uri)

    .. todo::

        How much more of :ref:`Registry's <Registry>` should Butler forward?


.. py:class:: ButlerConfiguration

    .. py:attribute:: collection

        The :ref:`CollectionTag <Collection>` of the input collection.

    .. py:attribute:: run

        The :ref:`Run` instance used for all outputs.

        May be ``None`` to construct a read-only Butler.

        The :ref:`Run's <Run>` :ref:`Collection` is always used as the input collection when a :ref:`Run` is provided.

    .. py:attribute:: templates

        A dict that maps :ref:`DatasetType` names to path templates, used to override :py:attr:`DatasetType.template` as obtained from the :ref:`Registry` when present.
