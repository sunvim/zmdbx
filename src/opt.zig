const c_import = @import("c.zig");
const c = c_import.c;

pub const Option = enum(c.enum_MDBX_option_t) {
    // OptMaxDB brief Controls the maximum number of named databases for the environment.
    //
    // details By default only unnamed key-value database could used and
    // appropriate value should set by `MDBX_opt_max_db` to using any more named
    // subDB(s). To reduce overhead, use the minimum sufficient value. This option
    // may only set after ref mdbx_env_create() and before ref mdbx_env_open().
    //
    // see mdbx_env_set_maxdbs() see mdbx_env_get_maxdbs()
    OptMaxDB = c.MDBX_opt_max_db,

    // OptMaxReaders brief Defines the maximum number of threads/reader slots
    // for all processes interacting with the database.
    //
    // details This defines the number of slots in the lock table that is used to
    // track readers in the the environment. The default is about 100 for 4K
    // system page size. Starting a read-only transaction normally ties a lock
    // table slot to the current thread until the environment closes or the thread
    // exits. If ref MDBX_NOTLS is in use, ref mdbx_txn_begin() instead ties the
    // slot to the ref MDBX_txn object until it or the ref MDBX_env object is
    // destroyed. This option may only set after ref mdbx_env_create() and before
    // ref mdbx_env_open(), and has an effect only when the database is opened by
    // the first process interacts with the database.
    //
    // see mdbx_env_set_maxreaders() see mdbx_env_get_maxreaders()
    OptMaxReaders = c.MDBX_opt_max_readers,

    // OptSyncBytes brief Controls interprocess/shared threshold to force flush the data
    // buffers to disk, if ref MDBX_SAFE_NOSYNC is used.
    //
    // see mdbx_env_set_syncbytes() see mdbx_env_get_syncbytes()
    OptSyncBytes = c.MDBX_opt_sync_bytes,

    // Opt_SYNC_PERIOD brief Controls interprocess/shared relative period since the last
    // unsteady commit to force flush the data buffers to disk,
    // if ref MDBX_SAFE_NOSYNC is used.
    // see mdbx_env_set_syncperiod() see mdbx_env_get_syncperiod()
    OptSyncPeriod = c.MDBX_opt_sync_period,

    // OptRpAugmentLimit brief Controls the in-process limit to grow a list of reclaimed/recycled
    // page's numbers for finding a sequence of contiguous pages for large data
    // items.
    //
    // details A long values requires allocation of contiguous database pages.
    // To find such sequences, it may be necessary to accumulate very large lists,
    // especially when placing very long values (more than a megabyte) in a large
    // databases (several tens of gigabytes), which is much expensive in extreme
    // cases. This threshold allows you to avoid such costs by allocating new
    // pages at the end of the database (with its possible growth on disk),
    // instead of further accumulating/reclaiming Garbage Collection records.
    //
    // On the other hand, too small threshold will lead to unreasonable database
    // growth, or/and to the inability of put long values.
    //
    // The `MDBX_opt_rp_augment_limit` controls described limit for the current
    // process. Default is 262144, it is usually enough for most cases.
    OptRpAugmentLimit = c.MDBX_opt_rp_augment_limit,

    // Opt_Loose_Limit brief Controls the in-process limit to grow a cache of dirty
    // pages for reuse in the current transaction.
    //
    // details A 'dirty page' refers to a page that has been updated in memory
    // only, the changes to a dirty page are not yet stored on disk.
    // To reduce overhead, it is reasonable to release not all such pages
    // immediately, but to leave some ones in cache for reuse in the current
    // transaction.
    //
    // The `MDBX_opt_loose_limit` allows you to set a limit for such cache inside
    // the current process. Should be in the range 0..255, default is 64.
    OptLooseLimit = c.MDBX_opt_loose_limit,

    // OptDpReserveLimit brief Controls the in-process limit of a pre-allocated memory items
    // for dirty pages.
    //
    // details A 'dirty page' refers to a page that has been updated in memory
    // only, the changes to a dirty page are not yet stored on disk.
    // Without ref MDBX_WRITEMAP dirty pages are allocated from memory and
    // released when a transaction is committed. To reduce overhead, it is
    // reasonable to release not all ones, but to leave some allocations in
    // reserve for reuse in the next transaction(s).
    //
    // The `MDBX_opt_dp_reserve_limit` allows you to set a limit for such reserve
    // inside the current process. Default is 1024.
    OptDpReserveLimit = c.MDBX_opt_dp_reserve_limit,

    // OptTxnDpLimit brief Controls the in-process limit of dirty pages
    // for a write transaction.
    //
    // details A 'dirty page' refers to a page that has been updated in memory
    // only, the changes to a dirty page are not yet stored on disk.
    // Without ref MDBX_WRITEMAP dirty pages are allocated from memory and will
    // be busy until are written to disk. Therefore for a large transactions is
    // reasonable to limit dirty pages collecting above an some threshold but
    // spill to disk instead.
    //
    // The `MDBX_opt_txn_dp_limit` controls described threshold for the current
    // process. Default is 65536, it is usually enough for most cases.
    OptTxnDpLimit = c.MDBX_opt_txn_dp_limit,

    // OptTxnDpInitial brief Controls the in-process initial allocation size for dirty pages
    // list of a write transaction. Default is 1024.
    OptTxnDpInitial = c.MDBX_opt_txn_dp_initial,

    // OptSpillMaxDenomiator brief Controls the in-process how maximal part of the dirty pages may be
    // spilled when necessary.
    //
    // details The `MDBX_opt_spill_max_denominator` defines the denominator for
    // limiting from the top for part of the current dirty pages may be spilled
    // when the free room for a new dirty pages (i.e. distance to the
    // `MDBX_opt_txn_dp_limit` threshold) is not enough to perform requested
    // operation.
    // Exactly `max_pages_to_spill = dirty_pages - dirty_pages / N`,
    // where `N` is the value set by `MDBX_opt_spill_max_denominator`.
    //
    // Should be in the range 0..255, where zero means no limit, i.e. all dirty
    // pages could be spilled. Default is 8, i.e. no more than 7/8 of the current
    // dirty pages may be spilled when reached the condition described above.
    OptSpillMaxDenomiator = c.MDBX_opt_spill_max_denominator,

    // OptSpillMinDenomiator brief Controls the in-process how minimal part of the dirty pages should
    // be spilled when necessary.
    //
    // details The `MDBX_opt_spill_min_denominator` defines the denominator for
    // limiting from the bottom for part of the current dirty pages should be
    // spilled when the free room for a new dirty pages (i.e. distance to the
    // `MDBX_opt_txn_dp_limit` threshold) is not enough to perform requested
    // operation.
    // Exactly `min_pages_to_spill = dirty_pages / N`,
    // where `N` is the value set by `MDBX_opt_spill_min_denominator`.
    //
    // Should be in the range 0..255, where zero means no restriction at the
    // bottom. Default is 8, i.e. at least the 1/8 of the current dirty pages
    // should be spilled when reached the condition described above.
    OptSpillMinDenominator = c.MDBX_opt_spill_min_denominator,

    // OptSpillParent4ChildDenominator brief Controls the in-process how much of the parent transaction dirty
    // pages will be spilled while start each child transaction.
    //
    // details The `MDBX_opt_spill_parent4child_denominator` defines the
    // denominator to determine how much of parent transaction dirty pages will be
    // spilled explicitly while start each child transaction.
    // Exactly `pages_to_spill = dirty_pages / N`,
    // where `N` is the value set by `MDBX_opt_spill_parent4child_denominator`.
    //
    // For a stack of nested transactions each dirty page could be spilled only
    // once, and parent's dirty pages couldn't be spilled while child
    // transaction(s) are running. Therefore a child transaction could reach
    // ref MDBX_TXN_FULL when parent(s) transaction has  spilled too less (and
    // child reach the limit of dirty pages), either when parent(s) has spilled
    // too more (since child can't spill already spilled pages). So there is no
    // universal golden ratio.
    //
    // Should be in the range 0..255, where zero means no explicit spilling will
    // be performed during starting nested transactions.
    // Default is 0, i.e. by default no spilling performed during starting nested
    // transactions, that correspond historically behaviour.
    OptSpillParent4ChildDenominator = c.MDBX_opt_spill_parent4child_denominator,

    // OptMergeThreshold16Dot16Percent brief Controls the in-process threshold of semi-empty pages merge.
    // warning This is experimental option and subject for change or removal.
    // details This option controls the in-process threshold of minimum page
    // fill, as used space of percentage of a page. Neighbour pages emptier than
    // this value are candidates for merging. The threshold value is specified
    // in 1/65536 of percent, which is equivalent to the 16-dot-16 fixed point
    // format. The specified value must be in the range from 12.5% (almost empty)
    // to 50% (half empty) which corresponds to the range from 8192 and to 32768
    // in units respectively.
    OptMergeThreshold16Dot16Percent = c.MDBX_opt_merge_threshold16_dot_16_percent,
};
