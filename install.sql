CREATE TABLE IF NOT EXISTS `jgr_reports` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `playerName` varchar(100) NOT NULL,
  `steamName` varchar(100) DEFAULT NULL,
  `serverId` int(11) DEFAULT NULL,
  `title` varchar(150) NOT NULL,
  `description` text NOT NULL,
  `priority` varchar(20) NOT NULL DEFAULT 'Baja',
  `status` varchar(20) NOT NULL DEFAULT 'Abierto',
  `adminCitizenid` varchar(50) DEFAULT NULL,
  `adminName` varchar(100) DEFAULT NULL,
  `close_reason` varchar(32) DEFAULT NULL,
  `closed_by_citizenid` varchar(50) DEFAULT NULL,
  `closed_by_name` varchar(100) DEFAULT NULL,
  `player_offline_since` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `jgr_report_messages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `report_id` int(11) NOT NULL,
  `sender` varchar(100) NOT NULL,
  `sender_id` int(11) DEFAULT NULL,
  `message` text NOT NULL,
  `is_admin` boolean NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `fk_report_id` (`report_id`),
  CONSTRAINT `fk_report_id` FOREIGN KEY (`report_id`) REFERENCES `jgr_reports` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
