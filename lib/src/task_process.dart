// Copyright 2015 Workiva Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

library dart_dev.src.task_process;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

class TaskProcess {
  Completer _donec = new Completer();
  Completer _errc = new Completer();
  Completer _outc = new Completer();
  Completer<int> _procExitCode = new Completer();
  Process _process;

  StreamController<String> _stdout = new StreamController();
  StreamController<String> _stderr = new StreamController();

  TaskProcess(String executable, List<String> arguments,
      {String workingDirectory}) {
    Process
        .start(executable, arguments, workingDirectory: workingDirectory)
        .then((process) {
      _process = process;
      process.stdout
          .transform(UTF8.decoder)
          .transform(new LineSplitter())
          .listen(_stdout.add, onDone: _outc.complete);
      process.stderr
          .transform(UTF8.decoder)
          .transform(new LineSplitter())
          .listen(_stderr.add, onDone: _errc.complete);
      _outc.future.then((_) => _stdout.close());
      _errc.future.then((_) => _stderr.close());
      process.exitCode.then(_procExitCode.complete);
      Future.wait([_outc.future, _errc.future, process.exitCode])
          .then((_) => _donec.complete());
    });
  }

  Future get done => _donec.future;

  Future<int> get exitCode => _procExitCode.future;

  Stream<String> get stderr => _stderr.stream;
  Stream<String> get stdout => _stdout.stream;

  Future<List<int>> getChildPids(List<int> pids) async{
    String executable = "pgrep";
    var args = [];
    for(int i in pids){
      args.add("-P");
      args.add("${i}");
    }
    TaskProcess pp = new TaskProcess(executable,args);
    List<int> cpids = new List<int>();
    pp.stdout.listen((l){
      try{
        int cpid = int.parse(l);
        cpids.add(cpid);
      }
      on Exception{
      }
    });
    await pp.done;
    if(cpids.length > 0){
      cpids = await getChildPids(cpids);
      cpids.addAll(pids);
      return cpids;
    }
    else return pids;
  }

  Future<bool> killAllChildren(int ppid) async{
    List<int> cpids = await getChildPids([ppid]);
    var args = ["-TERM"];
    cpids.remove(ppid);
    for(int i in cpids)
      args.add(i.toString());
    TaskProcess k = new TaskProcess("kill",args);
    await k.done;
    if(await k.exitCode ==0)
      return true;
    else
      return false;

  }

  bool kill([ProcessSignal signal = ProcessSignal.SIGTERM]) =>
      _process.kill(signal);
  Future killGroup()async {
    await killAllChildren(_process.pid);
//    kill();
//    TaskProcess l = new TaskProcess("pkill",["-P", "${_process.pid}"]);
//    TaskProcess a = new TaskProcess("ps",["-o","pgid=", "-p" ,"${_process.pid}"]);
//      a.stdout.listen((l) {
//        print(l);
//        int pgid = int.parse(l);
//        TaskProcess p = new TaskProcess("kill",["-TERM","-${pgid}"]);
//      });
//      a.stderr.listen((l) {
//        print(l);
//      });
//
//    await a.done;
//    try{_process.kill();}
//          on Exception{
//
//          }
  }
}
