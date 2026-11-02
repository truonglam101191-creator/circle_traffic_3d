import '../../domain/entities/circle_traffic_models.dart';
import '../../domain/repositories/stage_repository.dart';
import '../datasources/circle_traffic_stages.dart';
import '../datasources/circle_traffic_themes.dart';

/// Concrete implementation of [StageRepository] backed by static stage & theme catalogs.
class StageRepositoryImpl implements StageRepository {
  const StageRepositoryImpl();

  @override
  List<CTStageDefinition> get stages => kCTStages;

  @override
  List<CTGameThemeData> get themes => kCTThemes;

  @override
  CTStageDefinition stageById(int stageId) {
    final idx = (stageId - 1).clamp(0, kCTStages.length - 1);
    return kCTStages[idx];
  }

  @override
  CTGameThemeData themeForStage(int stageId) => ctThemeForStage(stageId);
}
