-- MySQL dump 10.11
--
-- Host: localhost    Database: rametook_firo
-- ------------------------------------------------------
-- Server version	5.0.45-Debian_1ubuntu3-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `modem_at_commands`
--

DROP TABLE IF EXISTS `modem_at_commands`;
CREATE TABLE `modem_at_commands` (
  `id` int(11) NOT NULL auto_increment,
  `modem_type_id` int(11) default NULL,
  `at_type` varchar(16) default NULL,
  `name` varchar(16) default NULL,
  `case_format` varchar(255) default NULL,
  `format` varchar(255) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=38 DEFAULT CHARSET=latin1;

--
-- Dumping data for table `modem_at_commands`
--

LOCK TABLES `modem_at_commands` WRITE;
/*!40000 ALTER TABLE `modem_at_commands` DISABLE KEYS */;
INSERT INTO `modem_at_commands` VALUES (1,1,'UNSOLIC','+CDS',NULL,'fo,message_ref,[\"number\"],[tora],\"service_time\",\"time\",status_report'),(2,1,'UNSOLIC','+CRING',NULL,'ring'),(4,1,'RESULT','+CMGR',NULL,'\"status\",others'),(5,1,'RESULT','+CMGR','status=REC (UN)?READ','\"status\"[,\"number\"],\"service_time\",language,encode,priority[,\"callback_number\"],length<CR><LF>data'),(6,1,'RESULT','+CMGR','status=STO (UN)?SENT','\"status\"[,\"number\"],\"time\",language,encode,priority[,\"callback_number\"],length<CR><LF>data'),(7,1,'RESULT','+CMGR','status=READ','\"status\",message_ref,\"number\",tora,\"service_time\",\"time\",status_report'),(8,1,'RESULT','+CMGS',NULL,'message_ref'),(9,1,'FINAL','+CME ERROR',NULL,'error'),(10,1,'FINAL','OK',NULL,NULL),(11,1,'FINAL','ERROR',NULL,NULL),(12,1,'FINAL','+CMS ERROR',NULL,'error'),(14,1,'COMMAND','+CMGR',NULL,'index'),(15,1,'COMMAND','+CMGS',NULL,'\"number\"[,length[,priority[,privacy[,reply[,\"callback_number\"]]]]]<CR>data<CTRL-Z>'),(16,1,'COMMAND','+CMGL',NULL,'\"status\"'),(17,1,'RESULT','+CMGL',NULL,'index,\"status\",others'),(18,1,'RESULT','+CMGL','status=(REC|STO) (UN)?(READ|SENT)','index,\"status\",\"oa\",lang,encod,length<CR><LF>data'),(19,1,'RESULT','+CMGL','status=READ','index,\"status\",fo,message_ref,\"scts\",\"dt\",st'),(20,1,'COMMAND','+CMGD',NULL,'index'),(21,1,'COMMAND','+CSQ',NULL,NULL),(22,1,'RESULT','+CSQ',NULL,'rssi,fer'),(23,1,'UNSOLIC','+CLIP',NULL,'\"number\",tora'),(24,2,'FINAL','OK',NULL,NULL),(25,2,'FINAL','ERROR',NULL,NULL),(26,2,'COMMAND','+CMGL',NULL,'status'),(27,2,'RESULT','+CMGL',NULL,'index,status,[alpha],length_pdu<CR><LF>data'),(28,2,'FINAL','+CME ERROR',NULL,'error'),(29,2,'FINAL','+CMS ERROR',NULL,'error'),(30,2,'COMMAND','+CMGR',NULL,'index'),(31,2,'RESULT','+CMGR',NULL,'status,[alpha],length_pdu<CR><LF>data'),(32,2,'COMMAND','+CSQ',NULL,NULL),(33,2,'RESULT','+CSQ',NULL,'rssi,ber'),(34,2,'COMMAND','+CMGD',NULL,'index'),(35,2,'COMMAND','+CMGS',NULL,'length_pdu<CR><PROMPT>data<CTRL-Z>'),(36,2,'RESULT','+CMGS',NULL,'message_ref'),(37,2,'UNSOLIC','+CDS',NULL,'length_pdu<CR><LF>data');
/*!40000 ALTER TABLE `modem_at_commands` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `modem_at_functions`
--

DROP TABLE IF EXISTS `modem_at_functions`;
CREATE TABLE `modem_at_functions` (
  `id` int(11) NOT NULL auto_increment,
  `modem_type_id` int(11) default NULL,
  `name` varchar(255) default NULL,
  `command_name` varchar(255) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=latin1;

--
-- Dumping data for table `modem_at_functions`
--

LOCK TABLES `modem_at_functions` WRITE;
/*!40000 ALTER TABLE `modem_at_functions` DISABLE KEYS */;
INSERT INTO `modem_at_functions` VALUES (1,1,'send_sms','+CMGS'),(2,1,'read_sms','+CMGR'),(3,1,'list_sms','+CMGL'),(4,1,'delete_sms','+CMGD'),(5,1,'sms_status_report','+CDS'),(6,1,'signal_quality','+CSQ'),(7,1,'ring_in','+CRING'),(8,1,'caller_id','+CLIP'),(9,2,'list_sms','+CMGL'),(10,2,'read_sms','+CMGR'),(11,2,'signal_quality','+CSQ'),(12,2,'sms_status_report','+CDS'),(13,2,'delete_sms','+CMGD'),(14,2,'send_sms','+CMGS');
/*!40000 ALTER TABLE `modem_at_functions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `modem_devices`
--

DROP TABLE IF EXISTS `modem_devices`;
CREATE TABLE `modem_devices` (
  `id` int(11) NOT NULL auto_increment,
  `identifier` varchar(255) default NULL,
  `modem_type_id` int(11) default NULL,
  `device` varchar(255) default NULL,
  `hostname` varchar(255) default NULL,
  `appname` varchar(255) default NULL,
  `baudrate` int(11) default NULL,
  `databits` int(11) default NULL,
  `stopbits` int(11) default NULL,
  `parity` int(11) default NULL,
  `active` int(11) default NULL,
  `init_command` varchar(255) default NULL,
  `signal_quality` int(11) default NULL,
  `last_refresh` datetime default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=latin1;

--
-- Dumping data for table `modem_devices`
--

LOCK TABLES `modem_devices` WRITE;
/*!40000 ALTER TABLE `modem_devices` DISABLE KEYS */;
INSERT INTO `modem_devices` VALUES (1,'WAVECOM MODEM; 800 1900; S/W VER: WISMOQ        WZ2.14I Jun 23 2005 09:17:07',1,'/dev/ttyS0','firo-studio',NULL,115200,8,1,0,0,'AT+CPMS=\"MT\",\"MO\"',21,'2007-09-06 19:45:45'),(2,' WAVECOM MODEM;  MULTIBAND  900E  1800 ; 543_09gg.Q2406A 1364028 020305 19:10',2,'/dev/ttyUSB0','chickenhost',NULL,115200,8,1,0,1,'AT+CPMS=\"SM\",\"SM\"',5,'2008-05-09 14:42:28'),(3,'Sony Ericsson K510; Sony Ericsson USB WMC Modem',2,'/dev/ttyACM0','chickenhost',NULL,115200,8,1,0,1,'AT+CPMS=\"ME\",\"ME\"',9,'2008-05-05 22:25:51'),(4,'WAVECOM MODEM; 800 1900; S/W VER: WISMOQ        WZ2.14I Jun 23 2005 09:17:07',1,'/dev/ttyS0','dev02',NULL,115200,8,1,0,1,'AT+CPMS=\"MT\",\"MO\"',26,'2008-05-09 14:42:52');
/*!40000 ALTER TABLE `modem_devices` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `modem_pdu_logs`
--

DROP TABLE IF EXISTS `modem_pdu_logs`;
CREATE TABLE `modem_pdu_logs` (
  `id` int(11) NOT NULL auto_increment,
  `modem_short_message_id` int(11) default NULL,
  `length_pdu` int(11) default NULL,
  `pdu` text,
  `first_octet` varchar(255) default NULL,
  `data_coding` varchar(255) default NULL,
  `udh` text,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=latin1;

--
-- Dumping data for table `modem_pdu_logs`
--

LOCK TABLES `modem_pdu_logs` WRITE;
/*!40000 ALTER TABLE `modem_pdu_logs` DISABLE KEYS */;
INSERT INTO `modem_pdu_logs` VALUES (1,1,117,'059126181642040C9126187500356900008050706153848270D02A53079AD2C3F4FA1C042FB7C3EB703AEC0641ABCC7918147493C3201D480A07C57037DBADC60291D3E834BDEE3E83C861791A440D9FD3E8B01B442FCBC36B745ACE0289CBEC7A1B442FCBDBE1797D0D0A8BDFEE72BBEC06994050A8131483955C','sms-deliver','general, 7-bit',NULL),(2,7,59,'059126120000040C912622077513110000805090410280802DC83428884D4E59A0FBBBCE2683F2EF3A889D5E9741F437685E769341E2F0780D6AE741F3F63CF403','sms-deliver','general, 7-bit',NULL),(3,9,48,'0031000C912622077513110000AA26C834C8C82C62932CD073CD022541F2329C9D07E5DF75D03D4D4783E8E8F43C140A01','sms-submit, v-rel, tp-srr','general, 7-bit',NULL),(4,9,25,'0006100C91262207751311805090412361828050904123718200','sms-status-report',NULL,NULL),(5,11,32,'0031000C912622077513110000AA14C3E671DA50F8400D850F04953E9B506A4301','sms-submit, v-rel, tp-srr','general, 7-bit',NULL),(6,11,25,'0006110C91262207751311805090419314828050904193248200','sms-status-report',NULL,NULL);
/*!40000 ALTER TABLE `modem_pdu_logs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `modem_short_messages`
--

DROP TABLE IF EXISTS `modem_short_messages`;
CREATE TABLE `modem_short_messages` (
  `id` int(11) NOT NULL auto_increment,
  `modem_device_id` int(11) NOT NULL,
  `status` varchar(255) collate utf8_unicode_ci default NULL,
  `message_ref` int(11) default NULL,
  `number` varchar(255) collate utf8_unicode_ci default NULL,
  `message` varchar(255) collate utf8_unicode_ci default NULL,
  `time` datetime default NULL,
  `service_time` datetime default NULL,
  `waiting_time` datetime default NULL,
  `callback_number` varchar(255) collate utf8_unicode_ci default NULL,
  `priority` int(11) default NULL,
  `privacy` int(11) default NULL,
  `trial` int(11) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `modem_short_messages`
--

LOCK TABLES `modem_short_messages` WRITE;
/*!40000 ALTER TABLE `modem_short_messages` DISABLE KEYS */;
INSERT INTO `modem_short_messages` VALUES (1,2,'INBOX',NULL,'628157005396','PUL: Status pemakaian PULsa Anda : Rp 187675, dihitung dari Tagihan terakhir, belum termasuk abonemen & PPN 10%.',NULL,'2008-05-07 16:35:48',NULL,NULL,NULL,NULL,NULL),(2,4,'INBOX',NULL,'4444',', Anda belum menginputkan ID Dealer, untuk menginputkan ketik :FL*IDdealer contoh FL*50001 kirim ke 4444',NULL,'2008-05-09 13:43:00',NULL,'4444',0,NULL,NULL),(3,4,'INBOX',NULL,'4444','Terima Kasih, status nomor Flexi Anda sudah teregistrasi dengan ID : 013059641585',NULL,'2008-05-09 13:43:00',NULL,'4444',0,NULL,NULL),(4,4,'INBOX',NULL,'4444','Status Registrasi anda sukses dengan ID 013059641585, Blokir untuk nomer ini telah dibuka',NULL,'2008-05-09 13:43:00',NULL,'4444',0,NULL,NULL),(5,4,'INBOX',NULL,'147','Registrasi anda telah berhasil. Anda bisa kembali menggunakan layanan Flexi Trendy.',NULL,'2008-05-09 13:43:00',NULL,'147',0,NULL,NULL),(6,4,'SENT',1,'083829022820','Hi AXIS, would you like to send back my sms!?','2008-05-09 14:27:44','2008-05-09 14:27:38',NULL,NULL,NULL,NULL,NULL),(7,2,'INBOX',NULL,'622270573111','Hi AXIS, would you like to send back my sms!?',NULL,'2008-05-09 14:20:08',NULL,NULL,NULL,NULL,NULL),(8,4,'INBOX',NULL,'083829022820','Message Sent Success 6283829022820 05/09 14:20:13',NULL,'2008-05-09 14:28:16',NULL,'Delivery Report',0,NULL,NULL),(9,2,'SENT',16,'622270573111','Hi FLEXI, Ok, I reply you with this!!!','2008-05-09 14:32:17','2008-05-09 14:32:16',NULL,NULL,NULL,NULL,NULL),(10,4,'INBOX',NULL,'083829022820','Hi FLEXI, Ok, I reply you with this!!!',NULL,'2008-05-09 14:32:20',NULL,'6283829022820',0,NULL,NULL),(11,2,'SENT',17,'622270573111','CMGS\r\n> \r\n> PROMPT\r\n','2008-05-09 14:39:42','2008-05-09 14:39:41',NULL,NULL,NULL,NULL,NULL),(12,4,'INBOX',NULL,'083829022820','CMGS\r\n> \r\n> PROMPT\r\n',NULL,'2008-05-09 14:39:44',NULL,'6283829022820',0,NULL,NULL);
/*!40000 ALTER TABLE `modem_short_messages` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `modem_types`
--

DROP TABLE IF EXISTS `modem_types`;
CREATE TABLE `modem_types` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(255) default NULL,
  `pdu_mode` tinyint(1) default NULL,
  `init_command` varchar(255) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=latin1;

--
-- Dumping data for table `modem_types`
--

LOCK TABLES `modem_types` WRITE;
/*!40000 ALTER TABLE `modem_types` DISABLE KEYS */;
INSERT INTO `modem_types` VALUES (1,'MultiTech CDMA Modem',0,'AT+CMEE=1;AT+CMGF=1;AT+CNMI=2,1,1,1,0'),(2,'Itegno GPRS Modem',1,'AT+CMEE=1;AT+CMGF=0;AT+CNMI=2,1,0,1,0');
/*!40000 ALTER TABLE `modem_types` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2008-05-09  7:42:40
