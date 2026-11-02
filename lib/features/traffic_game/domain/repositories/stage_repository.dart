import '../entities/circle_traffic_models.dart';

/// Abstract repository contract for accessing the 100 campaign stages and 10 district themes.
abstract class StageRepository {
  List<CTStageDefinition> get stages;
  List<CTGameThemeData> get themes;
  CTStageDefinition stageById(int stageId);
  CTGameThemeData themeForStage(int stageId);
}
