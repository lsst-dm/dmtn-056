
.. _Butler:

Butler
======

A high level object that provides access to the :ref:`Datasets <Dataset>` in a single :ref:`Collection`.

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

        :param DatasetLabel label: a :py:class:`DatasetLabel` that identifies the :ref:`Dataset` to retrieve.

        :param dict parameters: a dictionary of :ref:`StorageClass`-specific parameters that can be used to obtain a slice of the :ref:`Dataset`.

        :returns: an :ref:`InMemoryDataset`.

        Implemented as:

        .. code:: python

            try:
                handle = self.registry.find(self.config.inputCollection, label)
                parent = self.datastore.get(handle.uri, handle.type.storageClass, parameters) if handle.uri else None
                children = {name : self.datastore.get(childHandle, parameters) for name, childHandle in handle.components.items()}
                return handle.type.storageClass.assemble(parent, children, parameters)
            except NotFoundError:
                continue
            raise NotFoundError("DatasetRef {} not found in any input collection".format(datasetRef))

        .. todo::

            * Implementation requires all components to be able to handle (typically pass-through)
              parameters passed for the composite.  Could we instead get away with only passing those
              when getting the parent from the :ref:`Datastore`?

            * Recursive composites were broken by a minor update.
              Would probably not be hard to add back in if we decide we need them, but they'd make the logic a bit harder to follow so not worth doing now.

    .. py:method:: put(label, dataset, producer=None)

        :param DatasetLabel label: a :py:class:`DatasetLabel` that will identify the :ref:`Dataset` being stored.

        :param dataset: the :ref:`InMemoryDataset` to store.

        :param Quantum producer: the :ref:`Quantum` instance that produced the :ref:`Dataset`.  May be ``None`` for some :ref:`Registries <Registry>`.

        :returns: a :py:class:`DatasetHandle`

        Implemented as:

        .. code:: python

            ref = self.registry.expand(label)
            template = self.config.templates.get(ref.type.name, None)
            path = ref.makePath(self.config.outputCollection, template)
            uri, components = self.datastore.put(inMemoryDataset, ref.type.storageClass, path, ref.type.name)
            return self.registry.addDataset(self.config.outputCollection, ref, uri, components, producer)

    .. py:method:: markInputUsed(quantum, ref)

        Mark a :ref:`Dataset` as having been "actually" (not just predicted-to-be) used by a :ref:`Quantum`.

        :param Quantum quantum: the dependent :ref:`Quantum`.

        :param DatasetRef ref: the :ref:`Dataset` that is a true dependency of ``quantum``.

        Implemented as:

        .. code:: python

            handle = self.registry.find(self.config.inputCollection, ref)
            self.registry.markInputUsed(handle, quantum)

    .. todo::

        How much more of :ref:`Registry's <Registry>` should Butler forward?


.. py:class:: ButlerConfiguration

    .. py:attribute:: inputCollection

        The :ref:`CollectionTag <Collection>` of the input collection.

    .. py:attribute:: outputCollection

        The :ref:`CollectionTag <Collection>` of the output collection.  May be the same as :py:attr:`inputCollection`.

    .. py:attribute:: templates

        A dict that maps :ref:`DatasetType` names to path templates, used to override :py:attr:`DatasetType.template` as obtained from the :ref:`Registry` when present.
