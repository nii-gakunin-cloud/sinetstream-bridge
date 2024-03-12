/*
 * Copyright (C) 2023 National Institute of Informatics
 *
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

package jp.ad.sinet.stream.bridge;

import lombok.extern.java.Log;

import org.yaml.snakeyaml.Yaml;
import org.yaml.snakeyaml.DumperOptions;

import java.io.PrintWriter;
import java.io.StringWriter;
import java.util.Comparator;
import java.util.stream.Collectors;
import java.lang.AutoCloseable;

@Log
class Util {

    static void exit(int status) {
        exit(status, 1);
    }
    static void exit(int status, int delay) {
        if (delay > 0) {
            try {
                System.err.println("sleep " + delay);
                Thread.sleep(delay * 1000);
            }
            catch (InterruptedException ex) {
            }
        }
        System.err.println("exit " + status);
        System.exit(status);
    }

    static String getStackTrace(Throwable t) {
        StringWriter sw = new StringWriter();
        PrintWriter pw = new PrintWriter(sw);
        t.printStackTrace(pw);
        pw.flush();
        return sw.toString();
    }

    static String toYaml(Object o) {
        DumperOptions opt = new DumperOptions();
        opt.setAllowUnicode(true);
        opt.setPrettyFlow(true);
        opt.setWidth(120);
        Yaml yaml = new Yaml(opt);
        return yaml.dump(o);
    }

    static String exSummary(Throwable t) {
        return t.toString() + ":" + t.getMessage();
    }

    static void debugShowThread() {
        System.err.println("threads=" + debugDumpThread());
    }

    static String debugDumpThread() {
        return toYaml(Thread.getAllStackTraces().keySet().stream()
                        .sorted(Comparator.comparing(th -> th.getId()))
                        .map(th -> String.format("%d:%s%s",
                                                 th.getId(),
                                                 th.getName(),
                                                 th.isDaemon() ? " (daemon)" : ""))
                        .collect(Collectors.toList()));
    }
}
