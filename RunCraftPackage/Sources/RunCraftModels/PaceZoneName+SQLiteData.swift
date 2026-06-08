import SQLiteData
import VDOTEngine

// PaceZoneName lives in VDOTEngine (which intentionally doesn't link
// SQLiteData). These retroactive conformances let RunCraftModels store
// the enum as a column. The implementations are provided for free by
// SQLiteData's constrained extensions for `RawRepresentable<String>`.

extension PaceZoneName: QueryBindable {}
extension PaceZoneName: QueryDecodable {}
