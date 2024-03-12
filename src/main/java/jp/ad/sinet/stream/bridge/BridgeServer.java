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

import jp.ad.sinet.stream.api.*;
import jp.ad.sinet.stream.utils.MessageReaderFactory;
import jp.ad.sinet.stream.utils.MessageWriterFactory;

import lombok.extern.java.Log;

import java.util.ArrayList;
import java.util.Collection;
import java.util.concurrent.BlockingDeque;
import java.util.concurrent.LinkedBlockingDeque;
import java.util.concurrent.locks.Condition;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;
import java.util.concurrent.TimeUnit;
import java.util.function.Supplier;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.stream.Stream;

@Log
public class BridgeServer {

    class BridgeReader implements Runnable {
        private BridgeConfig bridgeConfig;
        private BridgeServer bridgeServer;
        private String serviceName;
        private Map<String, Object> serviceParams;
        private MessageReader reader;

        /*
        private Supplier<String> debugInjector;
        private int debugCounter;
        */

        BridgeReader(String serviceName, Map<String, Object> serviceParams, BridgeServer bridgeServer, BridgeConfig bridgeConfig) {
            this.bridgeConfig = bridgeConfig;
            this.bridgeServer = bridgeServer;
            this.serviceName = serviceName;
            this.serviceParams = serviceParams;
            openReader();
        }

        public boolean equals(Object o) {
            return o == this;
        }

        private void openReader() {
            assert(this.reader == null);
            log.fine(() -> "open reader: serviceName=" + serviceName);
            /*
            if (serviceName.equals("debugdebugdebug")) {
                debugInjector = () -> String.format("debug-%d-%d", ProcessHandle.current().pid(), ++debugCounter);
                return;
            }
            */
            MessageReaderFactory.MessageReaderFactoryBuilder builder = MessageReaderFactory.builder();
            builder.noConfig(true);
            builder.parameters(serviceParams);
            MessageReaderFactory factory = builder.build();
            this.reader = factory.getReader();
            log.fine(() -> "reader opened " + reader);
        }

        private void closeReader() {
            log.fine(() -> "closing reader " + reader);
            if (this.reader != null) {
                try {
                    this.reader.close();
                    log.fine(() -> "reader closed " + reader);
                }
                catch (Throwable t) {
                    log.severe(String.format("%s: ignore %s", this, t));
                }
                this.reader = null;
            }
        }

        @Override
        public String toString() {
            return "BridgeReader: " + serviceName;
        }

        public void run() {
            boolean running = true;
            bridgeServer.incActiveReaders();
            while (running) {
                String exmsg = "CLOSED";
                int debugCount = 0;
                while (true) {
                    try {
                        assert(reader != null);
                        Message m = reader.read();
                        if (m == null)
                            break;
                        log.fine(() -> String.format("reader %s: recved msg: %s", this, m));
                        int debugBridgeFailureRate = (int) serviceParams.getOrDefault("debugBridgeFailureRate", -1);
                        if (debugBridgeFailureRate > 0) {
                            if (++debugCount % debugBridgeFailureRate == 0)
                                throw new RuntimeException("XXX HIT debugBridgeFailureRate");
                        }
                        bridgeServer.forward(m, this);
                    }
                    catch (Throwable t) {
                        exmsg = Util.exSummary(t);
                        log.warning(String.format("%s caught exception: %s", this, Util.getStackTrace(t)));
                        break;
                    }
                }
                putLog(BridgeLogMsg.serviceDisconnected(serviceName, exmsg));
                running = false;
                closeReader();
                long delay = this.bridgeConfig.retryConnectMinDelay;
                for (int count = 0; count < this.bridgeConfig.retryConnectMax; count++) {
                    try {
                        log.info("sleep " + delay + " before trying to reconnect");
                        Thread.sleep(delay * 1000);
                        putLog(BridgeLogMsg.serviceReconnecting(serviceName, null));
                        openReader();
                        running = true;
                        putLog(BridgeLogMsg.serviceReconnected(serviceName, null));
                        break;
                    }
                    catch (Throwable t) {
                        log.warning(toString() + " caught exception in reconnecting: " + Util.getStackTrace(t));
                        putLog(BridgeLogMsg.serviceConnectionError(serviceName, Util.exSummary(t)));
                    }
                    delay = Math.min(delay * 2, this.bridgeConfig.retryConnectMaxDelay);
                }
            }
            log.severe(String.format("%s: terminate since too many retry", this));
            putLog(BridgeLogMsg.serviceTerminated(serviceName, null));
            bridgeServer.termReader(this);
        }

        void debugDisconnectForcibly() throws Exception {
            if (reader == null)
                return;
            assert(reader != null);
            try {
                System.err.println(String.format("XXX:A:this=%s:reader=%s", this.toString(), reader.toString()));
                ((SinetStreamBaseReader) reader).debugDisconnectForcibly();
                System.err.println(String.format("XXX:B:this=%s:reader=%s", this.toString(), reader.toString()));
            }
            catch (Exception ex) {
                System.err.println(String.format("XXX:C:this=%s:reader=%s", this.toString(), reader.toString()));
                log.warning("reader.debugDisconnectForcibly throws: " + Util.getStackTrace(ex));
            }
            assert(reader != null);
        }
    }

    class BridgeWriter implements Runnable {
        private BridgeConfig bridgeConfig;
        private BridgeServer bridgeServer;
        private String serviceName;
        private Map<String, Object> serviceParams;
        private BlockingDeque<Message> deq;
        private MessageWriter writer;

        BridgeWriter(String serviceName, Map<String, Object> serviceParams, BridgeServer bridgeServer, BridgeConfig bridgeConfig) {
            this.bridgeConfig = bridgeConfig;
            this.bridgeServer = bridgeServer;
            this.serviceName = serviceName;
            this.serviceParams = serviceParams;
            this.deq = new LinkedBlockingDeque<Message>(bridgeConfig.maxQLen);
            openWriter();
        }

        public boolean equals(Object o) {
            return o == this;
        }

        private void openWriter() {
            assert(this.writer == null);
            log.fine(() -> "open writer: serviceName=" + serviceName);
            MessageWriterFactory.MessageWriterFactoryBuilder builder = MessageWriterFactory.builder();
            builder.noConfig(true);
            builder.parameters(serviceParams);
            MessageWriterFactory factory = builder.build();
            this.writer = factory.getWriter();
            log.fine(() -> "writer opened " + writer);
        }

        private void closeWriter() {
            log.fine(() -> "closing writer " + writer);
            if (this.writer != null) {
                try {
                    this.writer.close();
                }
                catch (Throwable t) {
                    log.severe(String.format("%s: ignore %s", this, t));
                }
                this.writer = null;
            }
        }

        @Override
        public String toString() {
            return "BridgeWriter: " + serviceName;
        }

        void put(Message msg) throws Exception {
            try {
                deq.put(msg);
            }
            catch (InterruptedException ex) {
                throw ex;
            }
        }

        public boolean empty() {
            //return deq.empty();
            return deq.size() == 0;
        }

        public void run() {
            boolean running = true;
            bridgeServer.incActiveWriters();
            while (running) {
                int debugCount = 0;
                String exmsg = null;
                while (true) {
                    try {
                        log.fine(() -> "taking");
                        Message m = deq.take();
                        log.fine(() -> "taken: " + m);
                        int debugBridgeFailureRate = (int) serviceParams.getOrDefault("debugBridgeFailureRate", -1);
                        if (debugBridgeFailureRate > 0) {
                            if (++debugCount % debugBridgeFailureRate == 0)
                                throw new RuntimeException("XXX HIT debugBridgeFailureRate");
                        }
                        Message m3 = convertSample3(m);
                        writer.write(m3.getValue(), m3.getTimestampMicroseconds());
                        log.fine(() -> "written: " + m3);
                    }
                    catch (Throwable t) {
                        exmsg = Util.exSummary(t);
                        log.warning(toString() + " caught exception: " + Util.getStackTrace(t));
                        break;
                    }
                }
                putLog(BridgeLogMsg.serviceDisconnected(serviceName, exmsg));
                running = false;
                closeWriter();
                long delay = this.bridgeConfig.retryConnectMinDelay;
                for (int count = 0; count < this.bridgeConfig.retryConnectMax; count++) {
                    try {
                        log.info("sleep " + delay + " before trying to reconnect");
                        Thread.sleep(delay * 1000);
                        putLog(BridgeLogMsg.serviceReconnecting(serviceName, null));
                        openWriter();
                        putLog(BridgeLogMsg.serviceReconnected(serviceName, null));
                        running = true;
                        break;
                    }
                    catch (Throwable t) {
                        log.warning(toString() + " caught exception in reconnecting: " + Util.getStackTrace(t));
                        putLog(BridgeLogMsg.serviceConnectionError(serviceName, Util.exSummary(t)));
                    }
                    delay = Math.min(delay * 2, this.bridgeConfig.retryConnectMaxDelay);
                }
            }
            log.severe(String.format("%s: terminate since too many retry", this));
            putLog(BridgeLogMsg.serviceTerminated(serviceName, null));
            bridgeServer.termWriter(this);
        }

        void debugDisconnectForcibly() throws Exception {
            ((SinetStreamBaseWriter) writer).debugDisconnectForcibly();
        }

        Message convertSample3(Message msg) {
            return msg;
            /*
            if ((boolean) this.serviceParams.get("convertSample3")) {
                String value = (String) msg.getValue();
                value = value.toLowerCase();
                return new Message(value,
                                   msg.getTopic(),
                                   msg.getTimestampMicroseconds(),
                                   msg.getRaw());
            } else {
                return msg;
            }
            */
        }
    }

    boolean onDebug = true;  // XXX
    void forward(Message msg, BridgeReader reader) throws Exception {
        if (onDebug && debugFunction(msg))
            return;
        Message msg1 = convertSample1(msg, reader);
        if (msg1 == null)
            return;  // DROP
        synchronized (writerList) {
            for (BridgeWriter w : writerList) {
                Message msg2 = convertSample2(msg1, w);
                if (msg2 == null)
                    continue;  // DROP
                w.put(msg2);
            }
        }
    }

    Message convertSample1(Message msg, BridgeReader reader) {
        return msg;
        /*
        if ((boolean) reader.serviceParams.get("convertSample1")) {
            String value = (String) msg.getValue();
            value = value.toUpperCase();
            return new Message(value,
                               msg.getTopic(),
                               msg.getTimestampMicroseconds(),
                               msg.getRaw());
        } else {
            return msg;
        }
        */
    }

    Message convertSample2(Message msg, BridgeWriter writer) {
        return msg;
        /*
        int n = (int) writer.serviceParams.get("convertSample2");
        if (n < 0)
            return msg; // THRU
        int i = (int) writer.serviceParams.getOrDefault("convertSample2count", 0);
        i++;
        writer.serviceParams.put("convertSample2count", i);
        return i % n == 0 ? null  // DROP
                          : msg;
        */
    }

    boolean debugFunction(Message msg) {
        Object value = msg.getValue();
        if (value instanceof String) {
            String s = (String)value;
            try {
                if (s.startsWith("reader:debugDisconnectForcibly")) {
                    log.info("XXX accept command:" + s);
                    synchronized (readerList) {
                        for (BridgeReader r : readerList)
                            r.debugDisconnectForcibly();
                    }
                    return true;
                }
                if (s.startsWith("writer:debugDisconnectForcibly")) {
                    log.info("XXX accept command:" + s);
                    synchronized (writerList) {
                        for (BridgeWriter w : writerList)
                            w.debugDisconnectForcibly();
                    }
                    return true;
                }
            }
            catch (Exception ex) {
                log.info("failed: " + s + ": " + Util.getStackTrace(ex));
            }
        }
        return false;
    }

    class BridgeReporter extends BridgeWriter {
        BridgeReporter(String serviceName, Map<String, Object> serviceParams, BridgeServer bridgeServer, BridgeConfig bridgeConfig) {
            super(serviceName, serviceParams, bridgeServer, bridgeConfig);
        }

        @Override
        public String toString() {
            return "BridgeReporter";
        }

        void putLog(String msg) {
            log.fine(() -> "putLog:" + msg);
            try {
                put(new Message(msg, null, 0L, null));
            }
            catch (Exception ex) {
                System.err.println("reporting failure: msg=\"" + msg + "\":" + ex);
                log.warning("reporting failure: msg=\"" + msg + "\":" + ex);
            }
        }
    }

    private <R> R invokeWithLock(Lock lock, Supplier<R> f) {
        lock.lock();
        try {
            return f.get();
        }
        finally {
            lock.unlock();
        }
    }

    private Lock lock;
    private Condition cond;
    private BridgeConfig bridgeConfig;
    private BridgeReporter reporter;
    private List<BridgeReader> readerList;  // synchronized
    private List<BridgeWriter> writerList;  // synchronized
    private int activeReaders;
    private int activeWriters;

    private void incActiveReaders() {
        invokeWithLock(lock, () ->  {
            activeReaders++;
            cond.signalAll();
            return true;  // dummy
        });
    }
    private void incActiveWriters() {
        invokeWithLock(lock, () ->  {
            activeWriters++;
            cond.signalAll();
            return true;  // dummy
        });
    }
    private void listRemove(List lst, Object o) {
        invokeWithLock(lock, () ->  {
            boolean ok = lst.remove(o);
            assert (ok);
            if (ok)
                cond.signalAll();
            return true;  // dummy
        });
    }
    /*
    private void listRemove(List lst, Object o) {
        lock.lock();
        try {
            boolean ok = lst.remove(o);
            assert (ok);
            if (ok)
                cond.signalAll();
        }
        finally {
            lock.unlock();
        }
    }
    */

    BridgeServer(BridgeConfig bridgeConfig) {
        this.lock = new ReentrantLock();
        this.cond = this.lock.newCondition();
        this.bridgeConfig = bridgeConfig;
    }

    private void initReporter() {
        if (bridgeConfig.reportConfig == null)
            return;
        log.fine("initReporter");
        bridgeConfig.reportConfig.put("value_type", "text");  // overwrite
        try {
            this.reporter = new BridgeReporter(bridgeConfig.reportServiceName, bridgeConfig.reportConfig, this, bridgeConfig);
        }
        catch (Exception ex) {
            putLog(BridgeLogMsg.connectionError(bridgeConfig.reportServiceName, null));
            throw new RuntimeException("connection failure to the service \"" + bridgeConfig.reportServiceName + "\"", ex);
        }
        log.fine("initReporter:done");
    }
    private void initWriter() {
        log.fine("initWriter");
        this.writerList = new ArrayList<BridgeWriter>(bridgeConfig.writerConfigList.size());
        synchronized (writerList) {
            for (Map.Entry<String, Map<String, Object>> e : bridgeConfig.writerConfigList.entrySet()) {
                String serviceName = e.getKey();
                Map<String, Object> serviceParams = e.getValue();
                log.fine(() -> "initWriter:" + serviceName);
                try {
                    this.writerList.add(new BridgeWriter(serviceName, serviceParams, this, bridgeConfig));
                }
                catch (Exception ex) {
                    putLog(BridgeLogMsg.connectionError(/*"writer:" +*/ serviceName, null));
                    throw new RuntimeException("connection failure to the service \"" + serviceName + "\"", ex);
                }
                log.fine(() -> "initWriter:" + serviceName + ":done");
            }
        }
        log.fine("initWriter:done");
    }
    private void initReader() {
        log.fine("initReader");
        this.readerList = new ArrayList<BridgeReader>(bridgeConfig.readerConfigList.size());
        synchronized (readerList) {
            for (Map.Entry<String, Map<String, Object>> e : bridgeConfig.readerConfigList.entrySet()) {
                String serviceName = e.getKey();
                Map<String, Object> serviceParams = e.getValue();
                log.fine(() -> "initReader:" + serviceName);
                try {
                    readerList.add(new BridgeReader(serviceName, serviceParams, this, bridgeConfig));
                }
                catch (Exception ex) {
                    putLog(BridgeLogMsg.connectionError(/*"reader:" +*/ serviceName, null));
                    throw new RuntimeException("connection failure to the service \"" + serviceName + "\"", ex);
                }
                log.fine(() -> "initReader:" + serviceName + ":done");
            }
        }
        log.fine("initReader:done");
    }

    private void termWriter(BridgeWriter x) {
        synchronized (writerList) {
            listRemove(writerList, x);
        }
    }
    private void termReader(BridgeReader x) {
        synchronized (readerList) {
            listRemove(readerList, x);
        }
    }

    private String putLog(String msg) {
        log.fine(() -> "putLog: reporter=" + this.reporter);
        if (this.reporter != null)
            this.reporter.putLog(msg);
        return msg;
    }

    private Thread shutdownHook;

    void shutdown() {
        Util.debugShowThread();
        System.err.println("SHUTDOWN");
        //putLog(BridgeLogMsg.shutdown(null));
        //System.err.println("SHUTDOWN2");
    }

    void start() {
        log.info("starting");

        shutdownHook = new Thread(() -> this.shutdown());
        Runtime.getRuntime().addShutdownHook(shutdownHook);
        log.fine("addShutdownHook");

        initReporter();

        log.fine("spawn report thread");
        if (reporter != null)
            new Thread(reporter, reporter.toString()).start();

        initWriter();
        initReader();

        log.fine("spawn threads");
        synchronized (readerList) {
            Stream.of(readerList)
                  .flatMap(Collection::stream)
                  .forEach(x -> new Thread(x, x.toString()).start());
        }
        invokeWithLock(lock, () -> {
            // wait for all readers running
            while (activeReaders < readerList.size()) {
                log.fine(() -> String.format("activeReaders=%d < readerList.size()=%d", activeReaders, readerList.size()));
                try {
                    cond.await(1, TimeUnit.SECONDS); // XXX
                }
                catch (InterruptedException ex) {
                    BridgeLogMsg.terminated(this.bridgeConfig.bridgeServiceName, "Interrupted: " + ex);
                    Util.exit(1);
                }
            }
            log.fine("all readers running");
            return true;  // dummy
        });
        synchronized (writerList) {
            Stream.of(writerList)
                  .flatMap(Collection::stream)
                  .forEach(x -> new Thread(x, x.toString()).start());
        }
        invokeWithLock(lock, () -> {
            // wait for all writers running
            while (activeWriters < writerList.size()) {
                log.fine(() -> String.format("activeWriters=%d < writerList.size()=%d", activeWriters, writerList.size()));
                try {
                    cond.await(1, TimeUnit.SECONDS); // XXX
                }
                catch (InterruptedException ex) {
                    BridgeLogMsg.terminated(this.bridgeConfig.bridgeServiceName, "Interrupted: " + ex);
                    Util.exit(1);
                }
            }
            log.fine("all writers running");
            return true;  // dummy
        });
        log.fine("spawn threads:done");
        putLog(BridgeLogMsg.started(this.bridgeConfig.bridgeServiceName, null));
        watch();
        // never reach
    }

    public void watch() {
        log.fine("watching");
        invokeWithLock(lock, () -> {
            try {
                while (true) {
                    cond.await(1, TimeUnit.SECONDS); // XXX
                    log.finer("wakeup");
                    pollThread();
                }
            }
            catch (InterruptedException ex) {
                BridgeLogMsg.terminated(this.bridgeConfig.bridgeServiceName, "Interrupted: " + ex);
                Util.exit(1);
            }
            return true;  // dummy
        });
        // never reach
    }
    /*
    public void watch() {
        log.fine("watching");
        lock.lock();
        try {
            while (true) {
                cond.await(1, TimeUnit.SECONDS); // XXX
                log.finer("wakeup");
                pollThread();
            }
        }
        catch (InterruptedException ex) {
            BridgeLogMsg.terminated("Interrupted: " + ex);
            Util.exit(1);
        }
        finally {
            lock.unlock();
        }
        // never reach
    }
    */

    private void pollThread() {
        // expected: lock is acquired
        boolean goneWriter = false;
        boolean goneReader = false;
        synchronized (writerList) {
            log.finer(() -> "writerList.size=" + writerList.size());
            goneWriter = writerList.isEmpty();
        }
        if (goneWriter) {
            log.severe(putLog("all writers gone"));
        }
        synchronized (readerList) {
            log.finer(() -> "readerList.size=" + readerList.size());
            goneReader = readerList.isEmpty();
        }
        if (goneReader) {
            log.severe(putLog("all readers gone"));
        }
        if (goneReader || goneWriter) {
            Util.debugShowThread();
            putLog(BridgeLogMsg.terminated(this.bridgeConfig.bridgeServiceName, "all writers or all readers gone"));
            //System.err.println("exitting");
            //putLog("exitting");
            Util.exit(1);  // exit() causes invoking shutdownHook.
        }
    }

    static private void testlog() {
        log.warning("testlog:loglevel=warning");
        log.info("testlog:loglevel=info");
        log.config("testlog:loglevel=config");
        log.fine("testlog:loglevel=fine");
        log.finer("testlog:loglevel=finer");
        log.finest("testlog:loglevel=finest");
    }

}
