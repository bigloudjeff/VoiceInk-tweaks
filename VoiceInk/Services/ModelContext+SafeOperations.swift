import SwiftData
import os

extension ModelContext {
 /// Saves and logs on failure. Returns true on success.
 /// Use in views and fire-and-forget code where propagating errors isn't practical.
 @discardableResult
 func safeSave(context: String, logger: Logger) -> Bool {
  do {
   try save()
   return true
  } catch {
   logger.error("Save failed (\(context, privacy: .public)): \(error.localizedDescription, privacy: .public)")
   return false
  }
 }

 /// Saves or throws a `VoiceInkDataError.saveFailed`.
 /// Use in service code that should propagate errors to callers.
 func trySave(context: String) throws {
  do {
   try save()
  } catch {
   throw VoiceInkDataError.saveFailed(context: context, underlying: error)
  }
 }

 /// Fetches and logs on failure, returning an empty array as fallback.
 /// Use where empty results are an acceptable degradation.
 func safeFetch<T: PersistentModel>(
  _ descriptor: FetchDescriptor<T>,
  context: String,
  logger: Logger
 ) -> [T] {
  do {
   return try fetch(descriptor)
  } catch {
   logger.error("Fetch failed (\(context, privacy: .public)): \(error.localizedDescription, privacy: .public)")
   return []
  }
 }

 /// Fetches or throws a `VoiceInkDataError.fetchFailed`.
 /// Use in import/export paths where silent fallback would hide corruption.
 func tryFetch<T: PersistentModel>(
  _ descriptor: FetchDescriptor<T>,
  entity: String
 ) throws -> [T] {
  do {
   return try fetch(descriptor)
  } catch {
   throw VoiceInkDataError.fetchFailed(entity: entity, underlying: error)
  }
 }
}
