
#pragma once

// Include Bluespec's SceMi C++ api and all generated headers
#include "SceMiHeaders.h"
#include <vector>
#include <deque>

class DMATester {
 private:
  class QueueData {
  public:
    unsigned addr;
    unsigned id;
    unsigned words;
  };

  // local xactors
  InportQueueT<BusRequest >          m_request;
  OutportQueueT<BusResponse >        m_response;
  std::deque<class DMATester::QueueData>     m_outstanding;
  std::vector<long>                          m_data;

  // Shutdown Xactor
  ShutdownXactor                m_shutdown;

  unsigned int m_tid;

 public:
   // Constructor
  DMATester (SceMi *scemi) ;
  // Destructor
  ~ DMATester();

  void shutdown() {
    // Nothing to do here
  };


  bool read (const unsigned int addr, long & data);
  bool write (const unsigned int addr, const int data);

  bool fill (const unsigned int lo_addr,
             const unsigned int words,
             const long data,
             const long increment);

  bool dump (const unsigned int lo_addr,
             const unsigned int words,
             std::vector<long> & dout);

  // reactive interface -- does not block
  // all activity is queus
  void readQ(const unsigned int addr);
  void writeQ(const unsigned int addr, const long data);
  void fillQ (const unsigned int lo_addr,
              const unsigned int words,
              const long data,
              const long increment);
  void dumpQ (const unsigned int lo_addr,
              const unsigned int words);

  bool getResponseQ(unsigned &addr, std::vector<long> &vdata);

 private:
  void flushResponseQueue();
  bool getResponse (long &data);
  void readCore (const unsigned int addr, const unsigned transid);
  unsigned int nextTId () {
    if (m_tid >= (1 << 6) - 1) { 
      m_tid = 1;
    } 
    else {
      m_tid += 1;
    }
    return m_tid;
  }
};
