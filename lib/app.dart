import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task_empire/core/theme/app_theme.dart';
import 'package:task_empire/features/city/bloc/city_bloc.dart';
import 'package:task_empire/features/city/data/city_repository.dart';
import 'package:task_empire/features/progression/bloc/progression_bloc.dart';
import 'package:task_empire/features/progression/data/progression_repository.dart';
import 'package:task_empire/features/tasks/bloc/tasks_bloc.dart';
import 'package:task_empire/features/tasks/data/task_repository.dart';
import 'package:task_empire/home_shell.dart';

class TaskEmpireApp extends StatelessWidget {
  const TaskEmpireApp({required this.supabase, super.key});

  final SupabaseClient supabase;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<TaskRepository>(
          create: (_) => SupabaseTaskRepository(supabase),
        ),
        RepositoryProvider<CityRepository>(
          create: (_) => SupabaseCityRepository(supabase),
        ),
        RepositoryProvider<ProgressionRepository>(
          create: (_) => SupabaseProgressionRepository(supabase),
        ),
      ],
      child: const TaskEmpireView(),
    );
  }
}

class TaskEmpireView extends StatelessWidget {
  const TaskEmpireView({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<TasksBloc>(
          create: (context) =>
              TasksBloc(repository: context.read<TaskRepository>())
                ..add(const TasksStarted()),
        ),
        BlocProvider<CityBloc>(
          create: (context) =>
              CityBloc(repository: context.read<CityRepository>()),
        ),
        BlocProvider<ProgressionBloc>(
          create: (context) => ProgressionBloc(
            repository: context.read<ProgressionRepository>(),
          ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('ru'),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('ru')],
        onGenerateTitle: (_) => 'Task Empire',
        theme: AppTheme.light(),
        home: const HomeShell(),
      ),
    );
  }
}
