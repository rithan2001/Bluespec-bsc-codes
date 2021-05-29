#include "DMATester.h"

using namespace std;

DMATester::DMATester (SceMi *scemi) 
  : m_request    ("", "scemi_xrequest_inport", scemi)
  , m_response   ("", "scemi_xresponse_outport", scemi)
  , m_shutdown   ("", "scemi_xshutdown", scemi)
  , m_tid        (1)
{
}
// Destructor
DMATester::~DMATester()
{
}

void DMATester::flushResponseQueue()
{
  BusResponse response;
  while (m_response.getMessageNonBlocking(response)) {
    // Just flush
    //cout << "flushing: " << response << endl;
  } 
}
 
bool DMATester::getResponse (long &data)
{
  BusResponse response;
  bool stat = m_response.getMessageTimed(response,2);
  //cout << "Got: " << response << endl;
  if  ( response.m_error.get() ) {
    data = 0xdead0000;
  }
  else {
    data = response.m_data.get64();
  }
  return stat;
}
bool DMATester::getResponseQ (unsigned &addr, std::vector<long> &datav )
{
  BusResponse response;
  long data;
  bool stat, responseFromWrite;
  bool dataValid = false;
  // Drop responses which were from writes.
  while ( (stat = m_response.getMessageNonBlocking(response)) ) {
    responseFromWrite = (1 == response.m_write.get());
    if (responseFromWrite) continue; // Drop it.

    if ( response.m_error.get() ) {
      data = 0xdead0000;
    }
    else {
      data = response.m_data.get64();
    }
    m_data.push_back(data);

    if (m_data.size() >= m_outstanding.front().words) {
      addr = m_outstanding.front().addr;
      m_outstanding.pop_front();

      // Copy data to return vector
      datav.clear();
      std::vector<long> vtmp(m_data.begin(), m_data.end());
      datav = vtmp;
      m_data.clear();
      dataValid = true;
      break;
    }
  }

  return dataValid;
}

void DMATester::readCore (const unsigned addr, const unsigned  transid)
{
  BusRequest request ;
  request.m_address = addr;
  request.m_first   = true;
  request.m_burst   = 1;
  request.m_byteen  = -1;
  request.m_id      = transid;

  m_request.sendMessage(request);

}
void DMATester::readQ (const unsigned int addr)
{
  unsigned tid = nextTId();
  readCore(addr, tid);
  class QueueData d;
  d.addr  = addr;
  d.id    = tid;
  d.words = 1;
  m_outstanding.push_back(d);
}

bool DMATester::read (const unsigned int addr, long & data)
{
  // Flush any dead responses...
  flushResponseQueue();
  readCore(addr,0);
  bool stat = getResponse(data);

  return stat;
}

void DMATester::writeQ (const unsigned int addr, const long data)
{
  BusRequest request ;
  request.m_address = addr;
  request.m_write   = true;
  request.m_data    = data;
  request.m_first   = true;
  request.m_burst   = 1;
  request.m_byteen  = -1;

  m_request.sendMessage(request);
}
bool DMATester::write (const unsigned int addr, const int data)
{
  // Flush any dead responses...
  flushResponseQueue();
  writeQ(addr, data);
  long unused;
  bool stat  = getResponse(unused);
  return stat;
}

bool DMATester::fill (const unsigned int lo_addr,
                      const unsigned int words,
                      const long data_in,
                      const long incr)
{
  unsigned int addr, wc;
  int d;
  bool stat = true;
  for (addr = lo_addr, d = data_in, wc = 0; wc < words && stat; ++wc, addr += 4, d = d + incr ) {
    stat = write(addr,d);
  }
  return stat;
}

void DMATester::fillQ (const unsigned int lo_addr,
                       const unsigned int words,
                       const long data_in,
                       const long incr)
{
  unsigned int addr;
  unsigned int wc;
  int d;
  for (addr = lo_addr, d = data_in, wc = 0; wc < words; ++wc, addr += 4, d = d + incr ) {
    writeQ(addr,d);
  }
}

bool DMATester::dump (const unsigned int lo_addr,
                      const unsigned int words,
                      std::vector<long>  &dout)
{
  unsigned int addr, wc;
  int d;
  long data;
  bool stat = true;
  dout.clear();
  for (addr = lo_addr, wc = 0; wc < words && stat; ++wc, addr += 4 ) {
    stat = read(addr,data);
    if (stat) {
      dout.push_back(data);
    }
  }
  return stat;
}

void DMATester::dumpQ (const unsigned int lo_addr,
                       const unsigned int words
                       )
{
  unsigned int addr, wc;
  long data;
  unsigned tid = nextTId();

  class QueueData d;
  d.addr = lo_addr;
  d.id = tid;
  d.words = words;
  m_outstanding.push_back(d);
  for (addr = lo_addr, wc = 0; wc < words; ++wc, addr += 4 ) {
    readCore(addr, tid);
  }
}


