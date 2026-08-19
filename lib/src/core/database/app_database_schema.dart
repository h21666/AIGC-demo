class AppDatabaseSchema {
  const AppDatabaseSchema._();

  static const databaseName = 'aigc_studio.db';
  static const version = 2;

  static const createTableStatements = <String>[
    '''
CREATE TABLE prompts (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  negative_prompt TEXT,
  description TEXT,
  tags_json TEXT NOT NULL DEFAULT '[]',
  current_version_id TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  is_archived INTEGER NOT NULL DEFAULT 0
);
''',
    '''
CREATE TABLE prompt_versions (
  id TEXT PRIMARY KEY,
  prompt_id TEXT NOT NULL,
  version_number INTEGER NOT NULL,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  tags_json TEXT NOT NULL DEFAULT '[]',
  negative_prompt TEXT,
  change_note TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (prompt_id) REFERENCES prompts(id) ON DELETE CASCADE,
  UNIQUE (prompt_id, version_number)
);
''',
    '''
CREATE TABLE prompt_tags (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  created_at TEXT NOT NULL
);
''',
    '''
CREATE TABLE prompt_tag_links (
  prompt_id TEXT NOT NULL,
  tag_id TEXT NOT NULL,
  PRIMARY KEY (prompt_id, tag_id),
  FOREIGN KEY (prompt_id) REFERENCES prompts(id) ON DELETE CASCADE,
  FOREIGN KEY (tag_id) REFERENCES prompt_tags(id) ON DELETE CASCADE
);
''',
    '''
CREATE TABLE generation_tasks (
  id TEXT PRIMARY KEY,
  prompt_id TEXT NOT NULL,
  prompt_version_id TEXT NOT NULL,
  status TEXT NOT NULL,
  provider TEXT NOT NULL,
  request_json TEXT NOT NULL DEFAULT '{}',
  prompt_snapshot TEXT NOT NULL DEFAULT '{}',
  total_jobs INTEGER NOT NULL DEFAULT 0,
  completed_jobs INTEGER NOT NULL DEFAULT 0,
  failed_jobs INTEGER NOT NULL DEFAULT 0,
  retry_count INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  started_at TEXT,
  completed_at TEXT,
  error_message TEXT,
  FOREIGN KEY (prompt_id) REFERENCES prompts(id),
  FOREIGN KEY (prompt_version_id) REFERENCES prompt_versions(id)
);
''',
    '''
CREATE TABLE generation_jobs (
  id TEXT PRIMARY KEY,
  task_id TEXT NOT NULL,
  status TEXT NOT NULL,
  provider TEXT NOT NULL,
  prompt_version_id TEXT NOT NULL,
  request_json TEXT NOT NULL DEFAULT '{}',
  result_image_id TEXT,
  attempt INTEGER NOT NULL DEFAULT 0,
  max_attempts INTEGER NOT NULL DEFAULT 4,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  started_at TEXT,
  completed_at TEXT,
  error_message TEXT,
  FOREIGN KEY (task_id) REFERENCES generation_tasks(id) ON DELETE CASCADE,
  FOREIGN KEY (prompt_version_id) REFERENCES prompt_versions(id)
);
''',
    '''
CREATE TABLE generated_assets (
  id TEXT PRIMARY KEY,
  source TEXT NOT NULL,
  file_path TEXT NOT NULL,
  task_id TEXT,
  job_id TEXT,
  thumbnail_path TEXT,
  width INTEGER,
  height INTEGER,
  size_bytes INTEGER,
  mime_type TEXT,
  seed TEXT,
  prompt_snapshot TEXT,
  metadata_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL,
  exported_at TEXT,
  FOREIGN KEY (task_id) REFERENCES generation_tasks(id),
  FOREIGN KEY (job_id) REFERENCES generation_jobs(id)
);
''',
    '''
CREATE TABLE app_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
''',
    '''
CREATE TABLE app_logs (
  id TEXT PRIMARY KEY,
  level TEXT NOT NULL,
  message TEXT NOT NULL,
  context_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL
);
''',
  ];

  static const createIndexStatements = <String>[
    'CREATE INDEX idx_prompt_versions_prompt_id ON prompt_versions(prompt_id);',
    'CREATE INDEX idx_generation_tasks_status ON generation_tasks(status);',
    'CREATE INDEX idx_generation_tasks_updated_at ON generation_tasks(updated_at);',
    'CREATE INDEX idx_generation_jobs_task_id ON generation_jobs(task_id);',
    'CREATE INDEX idx_generation_jobs_status ON generation_jobs(status);',
    'CREATE INDEX idx_generated_assets_created_at ON generated_assets(created_at);',
    'CREATE INDEX idx_app_logs_created_at ON app_logs(created_at);',
  ];

  static const migrateFrom1To2Statements = <String>[
    'ALTER TABLE prompt_versions ADD COLUMN title TEXT NOT NULL DEFAULT \'\';',
    'ALTER TABLE prompt_versions ADD COLUMN tags_json TEXT NOT NULL DEFAULT \'[]\';',
    'ALTER TABLE generation_tasks ADD COLUMN prompt_snapshot TEXT NOT NULL DEFAULT \'{}\';',
    'ALTER TABLE image_assets RENAME TO generated_assets;',
    'UPDATE generation_jobs SET max_attempts = 4 WHERE max_attempts = 3;',
    'CREATE INDEX IF NOT EXISTS idx_generated_assets_created_at ON generated_assets(created_at);',
  ];
}
