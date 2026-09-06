import 'package:drift/drift.dart';

@DataClassName('ExerciseLibrary')
class ExerciseLibraryTable extends Table {
  TextColumn get id => text()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get externalId => text().unique()();
  TextColumn get name => text()();
  TextColumn get force => text().nullable()();
  TextColumn get level => text().nullable()();
  TextColumn get mechanic => text().nullable()();
  TextColumn get equipment => text().nullable()();
  TextColumn get primaryMuscles => text().nullable()();
  TextColumn get secondaryMuscles => text().nullable()();
  TextColumn get instructions => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get imageUrls => text().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
