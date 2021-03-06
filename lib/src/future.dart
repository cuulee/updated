import 'package:meta/meta.dart';

import 'update.dart';

/// Describes the behaviour of an update when one is already running.
enum UpdateOverride {
  /// If a new update is requested and there already an ongoing update, the new update is ignored
  /// and the previous one continues.
  ignore,

  /// If a new update is requested and there already an ongoing update, the previous one is cancelled
  /// and the new update starts.
  cancelPrevious,
}

/// Starts a sequence of updates by running the [updater] and raising a new [Update] after each step of its execution.
///
/// At each step of the updater execution, the [getUpdate] will be used to check if the task has been cancelled.
/// If so, the resulting stream will end without any new update.
///
/// If an update has already been started from the item returned by [getUpdate], then the behaviour is controlled
/// by the [override] parameters. The new update can whether be ignore, or cancel the previous execution.
///
/// An [optimisticValue] can be given to display an anticipated result during the loading phase.
Stream<Update<T>> update<T>({
  @required Future<T> Function() updater,
  @required Update<T> Function() getUpdate,
  UpdateOverride override = UpdateOverride.ignore,
  T optimisticValue,
}) {
  assert(getUpdate != null);
  assert(updater != null);
  return getUpdate().map(
    notLoaded: (state) async* {
      final updating = Updating.fromNotLoaded(
        state,
        id: _createId(),
        optimisticValue: optimisticValue,
      );
      yield updating;
      try {
        final result = await updater();
        if (!getUpdate().isCancelled(updating.id)) {
          yield Updated.fromUpdating(updating, result);
        }
      } catch (error, stackTrace) {
        if (!getUpdate().isCancelled(updating.id)) {
          yield FailedUpdate.fromUpdating(
            updating,
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
    },
    updating: (state) async* {
      if (override == UpdateOverride.cancelPrevious) {
        final updating = Updating.cancelling(
          state,
          id: _createId(),
          optimisticValue: optimisticValue,
        );
        yield updating;
        try {
          final result = await updater();
          if (!getUpdate().isCancelled(updating.id)) {
            yield Updated.fromUpdating(updating, result);
          }
        } catch (error, stackTrace) {
          if (!getUpdate().isCancelled(updating.id)) {
            yield FailedUpdate.fromUpdating(
              updating,
              error: error,
              stackTrace: stackTrace,
            );
          }
        }
      }
    },
    updated: (state) async* {
      final updating = Refreshing.fromUpdated(
        state,
        id: _createId(),
        optimisticValue: optimisticValue,
      );
      yield updating;
      try {
        final result = await updater();
        if (!getUpdate().isCancelled(updating.id)) {
          yield Updated.fromRefreshing(updating, result);
        }
      } catch (error, stackTrace) {
        if (!getUpdate().isCancelled(updating.id)) {
          yield FailedRefresh.fromRefreshing(
            updating,
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
    },
    failedRefresh: (state) async* {
      final updating = Refreshing.fromFailed(
        state,
        id: _createId(),
        optimisticValue: optimisticValue,
      );
      yield updating;
      try {
        final result = await updater();
        if (!getUpdate().isCancelled(updating.id)) {
          yield Updated.fromRefreshing(updating, result);
        }
      } catch (error, stackTrace) {
        if (!getUpdate().isCancelled(updating.id)) {
          yield FailedRefresh.fromRefreshing(
            updating,
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
    },
    failedUpdate: (state) async* {
      final updating = Updating.fromFailed(
        state,
        id: _createId(),
        optimisticValue: optimisticValue,
      );
      yield updating;
      try {
        final result = await updater();
        if (!getUpdate().isCancelled(updating.id)) {
          yield Updated.fromUpdating(updating, result);
        }
      } catch (error, stackTrace) {
        if (!getUpdate().isCancelled(updating.id)) {
          yield FailedUpdate.fromUpdating(
            updating,
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
    },
    refreshing: (state) async* {
      if (override == UpdateOverride.cancelPrevious) {
        final updating = Refreshing.cancelling(
          state,
          id: _createId(),
          optimisticValue: optimisticValue,
        );
        yield updating;
        try {
          final result = await updater();
          if (!getUpdate().isCancelled(updating.id)) {
            yield Updated.fromRefreshing(updating, result);
          }
        } catch (error, stackTrace) {
          if (!getUpdate().isCancelled(updating.id)) {
            yield FailedRefresh.fromRefreshing(
              updating,
              error: error,
              stackTrace: stackTrace,
            );
          }
        }
      }
    },
  );
}

extension _UpdateExtensions<T> on Update<T> {
  /// Test if the [id] is the same as the update one.
  bool isCancelled(int id) {
    return map(
      failedRefresh: (state) => state.id != id,
      failedUpdate: (state) => state.id != id,
      updated: (state) => state.id != id,
      refreshing: (state) => state.id != id,
      updating: (state) => state.id != id,
      notLoaded: (state) => false,
    );
  }
}

/// Create a new unique identifiers which will be associated to a new update.
int _createId() => _lastId++;

/// The unique identifiers associated to updates.
int _lastId = DateTime.now().millisecondsSinceEpoch -
    DateTime(2020, 1, 1).millisecondsSinceEpoch;
