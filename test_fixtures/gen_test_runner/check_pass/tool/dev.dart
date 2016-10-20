library test_generator_check_pass.tool.dev;

import 'package:dart_dev/dart_dev.dart' show dev, config;
import 'package:dart_dev/src/tasks/gen_test_runner/config.dart';

main(List<String> args) async {

  config.genTestRunner.configs = [
    new TestRunnerConfig(directory: 'test/', env: Environment.browser, genHtml: true)
  ];

  await dev(args);
}
