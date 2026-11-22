# Laravel on Two Servers: Deployment Assignment Report

**Name:** _Abbas Shafi_
**Live app:** http://laravelapp-abbasshafi.duckdns.org

I deployed a  Laravel app that stores users in MySQL on two AWS EC2 servers. The app runs on `app-vm`, the database runs on `db-vm`, every push to `main` is tested and deployed by GitHub Actions, the database is backed up every hour onto `app-vm`, and the Laravel logs clean themselves up every night.

## My setup

| | app-vm | db-vm |
|---|---|---|
| Job | nginx, PHP-FPM, Laravel, and the database backups | MySQL only |
| Private IP | 172.31.44.247 | 172.31.14.86 |
| Software | nginx 1.28, PHP 8.5, Laravel 13, Composer 2 | MySQL 8.4 |
| Size | t3.micro, 2 GB swap | t3.micro, 2 GB swap |


```
Browser --> laravelapp-abbasshafi.duckdns.org --> DNS --> app-vm (nginx + PHP-FPM + Laravel)
                                                            |
                                                            |  MySQL, port 3306, private network only
                                                            v
GitHub repo --> GitHub Actions --> SSH --> app-vm         db-vm (MySQL)

app-vm --(read-only backup user, every hour)--> db-vm
   '--> /var/backups/laravel (on app-vm)
```

---

## Task 1: Laravel and MySQL on one server

### What I did and why

I installed nginx, PHP-FPM and Laravel on app-vm and created a database and a MySQL user just for the app. That user is `laravel_db_prac`, with rights only on its own database and never root. Then I pointed the domain at the server.

### Proof:

| Done when | Proof |
|---|---|
| I can add data at the domain and see it on the page | T1-S5 |
| `/health` answers OK | T1-2S2 and the text below |
| The bare IP doesn't show the app | T1-S2, T1-S4 and the text below |
| Production mode, `.env` not downloadable and not world-readable | T1-S2, T1-S3 |

From my laptop:

```
$ curl -s -w ' HTTP %{http_code}\n' http://laravelapp-abbasshafi.duckdns.org/health
OK HTTP 200
$ curl -s -w ' HTTP %{http_code}\n' http://laravelapp-abbasshafi.duckdns.org/db-test
Connected! Users in the database: 1 HTTP 200
$ curl -sI --max-time 5 http://<app-vm public IP> ; echo "exit code: $?"
exit code: 52          (empty reply: nginx closed the connection without a page)
$ curl -sI http://laravelapp-abbasshafi.duckdns.org/.env | head -1
HTTP/1.1 403 Forbidden
```

![The app in the browser](screenshots/T1-S1.png)
*T1-S1: the app opens at the domain.*

![curl tests from my laptop](screenshots/T1-S2.png)
*T1-2S2: from my laptop. The domain answers, `/health` gives OK, `/db-test` shows the user count, the bare IP gives an empty reply, and `/.env` gives 403.*

![.env and production mode](screenshots/T1-S3.png)
*T1-S3: on app-vm, `APP_ENV=production`, `APP_DEBUG=false`, `APP_URL` is the domain, `.env` is `-rw-r----- ubuntu www-data`, and the web workers run as `www-data`.*

![nginx server blocks](screenshots/T1-S4.png)
*T1-24: the app's `server_name` and the `default_server` block that returns 444.*

![Adding data through the app](screenshots/T1-S5.png)

*T1-S5: the `/users` page after I added a user through the form. The new user appears in the list.*

---

## Task 2: Moving the database to db-vm

### What I did and why

I created db-vm, installed MySQL there, and moved the data across.

### Proof for "Done when"

| Done when | Proof |
|---|---|
| The app works and shows all the Task 1 data, with MySQL on app-vm stopped | T2-S8 |
| The data comes from db-vm | T2-S9, T2-S9b, plus the text evidence below |
| MySQL on db-vm only accepts app-vm | T2-S5, T2-S6, T2-S7 |

The settings on db-vm, copied from the terminal:

```
$ sudo grep -rE '^\s*bind-address' /etc/mysql/
/etc/mysql/mysql.conf.d/mysqld.cnf:bind-address = 172.31.14.86

$ sudo ss -tlnp | grep 3306
LISTEN  127.0.0.1:33060    mysqld     (local only: MySQL's X protocol)
LISTEN  172.31.14.86:3306  mysqld     (the private IP only, not 0.0.0.0)

$ SELECT user,host FROM mysql.user;
laravel_backup    172.31.44.247
laravel_db_prac   172.31.44.247
(plus the built-in system accounts, all on localhost)

$ SHOW GRANTS ...
laravel_db_prac@172.31.44.247 : ALL PRIVILEGES on laravel_db_prac.* only
laravel_backup@172.31.44.247  : SELECT, SHOW VIEW, EVENT, TRIGGER on laravel_db_prac.* only
```

From my laptop, the connection to MySQL on db-vm times out:

```
$ nc -zv -w 5 <db-vm public IP> 3306
nc: connect to <db-vm public IP> port 3306 (tcp) timed out: Operation now in progress
```

Laravel itself reports where its data comes from (`php artisan db:show`):

```
MySQL 8.4.11    Connection: mysql    Database: laravel_db_prac
Host: 172.31.14.86    Port: 3306    Username: laravel_db_prac    Tables: 9
```

`php artisan migrate:status` shows all three migrations as `Ran`. With MySQL on app-vm stopped, `/db-test` still returns `Connected! Users in the database: 1`, so the data can only come from db-vm. On app-vm, after a reboot:

```
$ systemctl is-active mysql ; systemctl is-enabled mysql
inactive
disabled
```

![db-vm MySQL settings and users](screenshots/T2-S5.png)
*T2-S5: on db-vm, the `bind-address`, the listening sockets, the user list, and the app user's grants.*

![Port 3306 times out from my laptop](screenshots/T2-S6.png)
*T2-S6: from my laptop, a connection to db-vm's MySQL port times out.*

![Security group](screenshots/T2-S7.png)
*T2-S7: db-vm's security group. Port 3306 is open only to app-vm.*

![Local MySQL stopped, app still works](screenshots/T2-S8.png)
*T2-S8: on app-vm, `mysql` is inactive and disabled, and `/health` and `/db-test` still work. So the data has to come from db-vm.*

![Connection counter on db-vm goes up](screenshots/T2-S9.png)
*T2-S9: on db-vm, the connection counter for the app user goes up each time I load a page.*

![artisan db:show](screenshots/T2-S9b.png)
*T2-S9b: Laravel reports its database host as `172.31.14.86`.*

---

## Task 3: Deploying updates with GitHub Actions

### What I did and why

The code is in a private GitHub repository. `.gitignore` excludes `.env`, `vendor/` and `*.log`, and `git ls-files` confirms none of them are tracked. I use two workflows:

1. **CI** runs on every push or pull request to `main`. 
2. **Deploy** runs only after CI finishes successfully on `main`.


### Proof for "Done when"

| Done when | Proof |
|---|---|
| Private repo, instructor added, no secrets committed | T3-S10, T3-S11, T3-S12 |
| Workflow: push to main, manual start, concurrency, migrate, caches, health check | T3-S13, T3-S14, T3-S15 |
| Update 1: a visible change appears without logging in to a server | T3-S16, T3-S17 |
| Update 2: a new column with a migration, run by the workflow | T3-S18, T3-S19, T3-S19B |
| Broken update fails, then the fix goes green through Git | T3-S20, T3-S21 |

![Collaborators and private repo](screenshots/T3-S10.png)
*T3-S10: the repo is private and my instructor is a collaborator.*

![Actions secrets](screenshots/T3-S11.png)
*T3-S11: the secret names. GitHub hides the values.*

![Nothing sensitive is tracked](screenshots/T3-S12.png)
*T3-S12: `git ls-files` finds no `.env`, `vendor/` or logs, and `.gitignore` lists them.*

![deploy.yml](screenshots/T3-S13.png)
*T3-S13: the deploy workflow, showing the `main` trigger, manual start, concurrency, migrate, caches and health check.*

![Actions list](screenshots/T3-S14.png)
*T3-S14: the Actions tab with green runs.*

![Deploy run expanded](screenshots/T3-S15.png)
*T3-S15: a green Deploy run with all its steps, including "Health check".*

### Update 1: a visible change

I changed what a page shows, pushed it from my laptop, and did not log in to any server. CI ran, then Deploy ran, and the change appeared on the live site.

![Update 1 pipeline](screenshots/T3-S16.png)

*T3-S16: CI and Deploy both green for Update 1.*

![Update 1 live](screenshots/T3-S17.png)

*T3-S17: the change is live at the domain.*

### Update 2: a new database column

I added a migration that creates a nullable `phone` column on the `users` table, and a page that reports whether the column exists. The migration ran inside the Deploy workflow, not by hand.

![Migration in the deploy log](screenshots/T3-S18.png)

*T3-S18: the Deploy log showing `php artisan migrate --force` running the new migration.*

![New column used on a page](screenshots/T3-S19.png)

*T3-S19: the page shows that the `phone` column exists.*

![migrate:status](screenshots/T3-S19B.png)

*T3-S19B: on app-vm, `migrate:status` lists the new migration as `Ran`.*

### The broken update, and the fix

I pushed a deliberate syntax error. CI turned red and Deploy never started, so the live site kept working the whole time. Then I fixed it through Git with `git revert` and a push, never by editing files on the server, and everything went green again.

![Broken update](screenshots/T3-S20.png)

*T3-S20: CI is red, Deploy did not run, and `/health` still answers OK.*

![Run history](screenshots/T3-S21.png)

*T3-S21: the Actions list shows green, green, red, then green after the revert.*

---

## Task 4: Backups and the disaster drill

### What I did

A script on app-vm, `laravel-db-backup.sh`, connects to db-vm and dumps the database. It stores the backups on app-vm so they survive if db-vm dies.

### Proof for "Done when"

| Done when | Proof |
|---|---|
| Backups appear on app-vm on schedule | T4-S1, T4-S2, and the listing below |
| Only the backup user can read them | T4-S1 |
| Failed backups are detected, deleted and logged | T4-S3 |
| Old backups are deleted automatically | T4-S4 |
| The drill is done and written up | The drill section below |

This is the backup folder on app-vm. The hourly files at minute 5 show the schedule working on its own:

```
drwx------ 2 root root 4096 Oct 31 16:05 .
-rw------- 1 root root 2319 Oct 30 16:57 laravel_db_20261030_165743.sql.gz
-rw------- 1 root root 2317 Oct 31 02:00 laravel_db_20261031_020002.sql.gz
-rw------- 1 root root 4614 Oct 31 10:35 laravel_db_20261031_103510.sql.gz
-rw------- 1 root root 4739 Oct 31 10:44 laravel_db_20261031_104414.sql.gz
-rw------- 1 root root 4848 Oct 31 11:05 laravel_db_20261031_110501.sql.gz
-rw------- 1 root root 4848 Oct 31 12:05 laravel_db_20261031_120501.sql.gz
-rw------- 1 root root 4848 Oct 31 13:05 laravel_db_20261031_130502.sql.gz
-rw------- 1 root root 4848 Oct 31 14:05 laravel_db_20261031_140502.sql.gz
-rw------- 1 root root 4849 Oct 31 15:05 laravel_db_20261031_150501.sql.gz
-rw------- 1 root root 5195 Oct 31 16:05 laravel_db_20261031_160501.sql.gz
```

And the start of the backup log, from `/var/log/laravel-db-backup.log`:

```
Sat Oct 31 02:00:03 UTC 2026: Backup successful: /var/backups/laravel/laravel_db_20261031_020002.sql.gz
Sat Oct 31 10:35:10 UTC 2026: Starting database backup
Sat Oct 31 10:35:11 UTC 2026: Backup successful: /var/backups/laravel/laravel_db_20261031_103510.sql.gz
```

![Backup folder](screenshots/T4-S1.png)
*T4-S1: the backup folder is root-only, and the files are timestamped and compressed.*

![Script and cron](screenshots/T4-S2.png)
*T4-S2: the backup script (no password in it) and the hourly cron line.*

![Failure test](screenshots/T4-S3.png)
*T4-S3: a run with a wrong credentials path fails, leaves no partial file behind, and logs the error.*

![Retention](screenshots/T4-S4.png)
*T4-S4: a fake 9-day-old backup is deleted automatically, and the log names it.*

### The disaster drill

All times are UTC, on 31 October 2026 unless noted.

**1. Backups and data.** Backups had run. The two I had at the time were `laravel_db_20261030_165743.sql.gz` (30 Oct, 16:57) and `laravel_db_20261031_020002.sql.gz` (31 Oct, 02:00). Neither contains any rows in the `users` table (I counted 0 `INSERT INTO users` statements in each).

**2. db-vm goes down.** I stopped MySQL on db-vm. The MySQL journal on db-vm records it:

```
Oct 31 03:51:39 systemd[1]: Stopping mysql.service - MySQL Community Server...
Oct 31 03:51:40 systemd[1]: Stopped mysql.service - MySQL Community Server.
```

**3. Bringing the app back using only what was on app-vm.** I started the MySQL server I'd stopped in Task 2, created the database `laravel_db_prac`, and restored the backup `laravel_db_20261030_165743.sql.gz`. All 9 tables came back. I made a temporary local MySQL user, pointed Laravel's `.env` at `127.0.0.1`, and rebuilt the config cache. All three migrations showed `Ran`, and the site answered while db-vm was still down:

```
$ curl http://laravelapp-abbasshafi.duckdns.org/health
OK          (HTTP 200)
$ curl http://laravelapp-abbasshafi.duckdns.org/db-test
Connected! Users in the database: 0
```

To prove the restored copy accepts writes, I added a test user ("Disaster Recovery Test") to the local database. `/db-test` then said `Users in the database: 1`.

> The brief says to restore the newest backup. I used the 16:57 one instead of the 02:00 one. Both contain the same user data (none), so the result would have been the same.

**4. Downtime and data lost.**

- **Downtime in the first run:** visitors saw no error. I had prepared the local copy and switched Laravel to it at about 03:49, shortly before I stopped db-vm at 03:51:39 (`.env` was last changed at 03:49). Laravel's own log confirms it: it recorded no database connection errors between 03:51 and 04:25.
- **Data lost:** the most that can be lost is whatever was written to db-vm after the last backup and before it went down. Before the move back, db-vm held no rows in `users`, which matches the backups (the safety copy I took of db-vm before importing has no `INSERT INTO users` statements). So no data was lost in this drill. The only user record is the one I created in the restored copy during the outage.

Because I switched to the local copy before stopping db-vm, I did not capture a failing health check in the first run. So I **repeated the outage on purpose** to show the app really does go down without its database. The db-vm journal shows MySQL stopped at 10:28:02 and started again at 10:28:25, about 23 seconds:

```
Oct 31 10:28:02 systemd[1]: Stopping mysql.service - MySQL Community Server...
Oct 31 10:28:06 systemd[1]: Stopped mysql.service - MySQL Community Server.
Oct 31 10:28:25 systemd[1]: Started mysql.service - MySQL Community Server.
```

Laravel's log shows the matching failures. These are the minutes in which Laravel could not connect to MySQL (error `SQLSTATE[HY000] [2002]`):

```
2026-10-30 13:03     (earlier: MySQL had been killed for lack of memory, before I added swap)
2026-10-31 10:28     (the repeated outage)
```

**5. Moving the database back to db-vm.** I started MySQL on db-vm again. The journal shows:

```
Oct 31 04:25:23 systemd[1]: Starting mysql.service - MySQL Community Server...
Oct 31 04:25:25 systemd[1]: Started mysql.service - MySQL Community Server.
```

Then I put the site into maintenance mode, dumped the recovered local database (including the test user from the outage), imported it into db-vm, and checked it there. db-vm shows all 9 tables and the test user, created while the app was running on the local copy:

```
id  name                    email                 created_at
 1  Disaster Recovery Test  dr-test@example.com   2026-10-31 03:55:44
```

I switched `.env` back to `DB_HOST=172.31.14.86` with the app's own user, rebuilt the config cache, and brought the site up. Last, I removed the temporary local MySQL account and stopped and disabled local MySQL again. So the data created during the outage was not lost.

---

## Task 5: Logs cleanup

### What I did and why

- **One log file per day.** I set `LOG_CHANNEL=daily` in `.env`, so Laravel writes `laravel-YYYY-MM-DD.log` instead of one file that grows forever. The folder on app-vm now holds files like `laravel-2026-10-31.log`.
- **A nightly job.** `scripts/cleanup-logs.sh` runs from root's crontab at 02:15 every night (`15 2 * * * /var/www/laravelapp/scripts/cleanup-logs.sh`). It does three things:
  1. **Compresses** every daily log except today's.
  2. **Deletes** compressed logs older than 14 days.
  3. **Warns** in its own log (`/var/log/laravel-log-cleanup.log`) if the logs folder is bigger than 500 MB.
- **It can't delete the wrong thing.** The script only touches files that match `laravel-*.log` and `laravel-*.log.gz`. `.gitignore` and anything else in the folder is left alone.
- **Safe to run twice.** After the first run there is nothing left to compress or delete, so the second run changes nothing.
- **Log permissions.** Both the web server (`www-data`) and my own user (`ubuntu`) write to `storage/logs`. I gave both users access with ACLs, so a file created by one can still be written by the other. Without this, Laravel failed with "could not be opened in append mode".

### Proof for "Done when"

This is the setup on app-vm:

```
$ grep ^LOG_CHANNEL .env
LOG_CHANNEL=daily

$ sudo crontab -l | grep -v '^#'
15 2 * * * /var/www/laravelapp/scripts/cleanup-logs.sh
5 * * * * /usr/local/bin/laravel-db-backup.sh
```

To show the cleanup working, I created fake old files in the logs folder: two logs dated 3 and 5 days ago (26 and 28 Oct) and a compressed log dated 20 days ago (11 Oct). I had run the demo once before, which is why compressed copies of the 26 and 28 Oct logs were already there; `gzip -f` replaces them. Then I ran the script twice:

```
### BEFORE
-rwxrwxr-x 1 ubuntu   ubuntu       14 Oct 31 05:02 .gitignore
-rw-r--r-- 1 root     root          0 Oct 11 16:09 laravel-2026-10-11.log.gz
-rw-r--r-- 1 root     root          5 Oct 26 16:09 laravel-2026-10-26.log
-rw-r--r-- 1 root     root         48 Oct 26 05:06 laravel-2026-10-26.log.gz
-rw-r--r-- 1 root     root          5 Oct 28 16:09 laravel-2026-10-28.log
-rw-r--r-- 1 root     root         48 Oct 28 05:06 laravel-2026-10-28.log.gz
-rw-r--r-- 1 www-data www-data 159147 Oct 31 10:28 laravel-2026-10-31.log
-rw-rw-r-- 1 ubuntu   ubuntu    64713 Oct 31 03:45 laravel.log

### RUN 1
-rwxrwxr-x 1 ubuntu   ubuntu       14 Oct 31 05:02 .gitignore
-rw-r--r-- 1 root     root         48 Oct 26 16:09 laravel-2026-10-26.log.gz
-rw-r--r-- 1 root     root         48 Oct 28 16:09 laravel-2026-10-28.log.gz
-rw-r--r-- 1 www-data www-data 159147 Oct 31 10:28 laravel-2026-10-31.log
-rw-rw-r-- 1 ubuntu   ubuntu    64713 Oct 31 03:45 laravel.log

### RUN 2 (no change)
(identical to RUN 1)
```

What happened:

- **Run 1** compressed the two old `.log` files into `.log.gz`, and deleted the 20-day-old `laravel-2026-10-11.log.gz`.
- Today's log (`laravel-2026-10-31.log`), `.gitignore` and the old single `laravel.log` were not touched.
- **Run 2** changed nothing.

Then I ran the script with the size limit set to 0 MB, which forces the warning. This is the script's own log:

```
2026-10-31 16:09:54 compressed laravel-2026-10-28.log
2026-10-31 16:09:54 compressed laravel-2026-10-26.log
2026-10-31 16:09:54 deleted laravel-2026-10-11.log.gz
2026-10-31 16:09:55 WARNING: /var/www/laravelapp/storage/logs is 1 MB (limit 0 MB)
```

### How Ubuntu already cleans the web server's and MySQL's logs in `/var/log`

Ubuntu runs `logrotate` once a day from a systemd timer (`logrotate.timer`, which shows up in `systemctl list-timers`). Each package, including nginx and MySQL, ships a small config file in `/etc/logrotate.d/`. That file says how often to rotate its log, how many old copies to keep, and whether to compress them. When a copy is older than the limit, it is deleted automatically. So nginx's and MySQL's logs can't fill the disk either. You can read the exact numbers with `cat /etc/logrotate.d/nginx`. The systemd journal also has its own size limit.

---

## Does everything still work after a restart?

I designed it so that nothing depends on a manual start:

- nginx, PHP-FPM and cron on app-vm, and MySQL on db-vm, are all enabled systemd services.
- MySQL on app-vm is disabled on purpose and stays off after a reboot.
- The hourly backup and the nightly cleanup are cron jobs, which survive reboots.
- All settings (`.env`, nginx config, MySQL config, the security group) are stored on disk or in AWS, not in memory.
- I restart the servers with `reboot`, not stop and start. A stop and start can change a server's public IP unless an Elastic IP is attached, which would also break the DNS record.

I rebooted both servers. After the reboot, app-vm showed:

```
ubuntu@app-vm:~$ hostname
app-vm
$ systemctl is-active nginx php8.5-fpm cron mysql
active
active
active
inactive                 (mysql is off on purpose)
$ systemctl is-enabled mysql
disabled
$ sudo crontab -l | grep -v '^#'
15 2 * * * /var/www/laravelapp/scripts/cleanup-logs.sh
5 * * * * /usr/local/bin/laravel-db-backup.sh
```

and db-vm showed:

```
ubuntu@db-vm:~$ hostname; systemctl is-active mysql
db-vm
active
```

The new hostnames stayed after the reboot, both cron jobs were still there, and the backups carried on every hour from minute 5.

---

## Answers to the questions

**1. Why should the app's MySQL user on db-vm only be allowed from app-vm's address?**

In MySQL, an account is a user name plus the host it may connect from. If the app's user were allowed from anywhere (`%`), then anyone who learned or guessed the password could log in from any machine. By tying it to `172.31.44.247`, the password is useless from every other machine, even if it leaks. It is one more layer on top of the other two I use: `bind-address` stops MySQL listening on the public interface, and the security group blocks port 3306 from everyone except app-vm. If one layer is misconfigured, the others still protect the data.

**2. In the broken update, was the live site affected? Why, or why not? What would I change in the workflow so broken code never reaches app-vm?**

No, the live site was not affected. I pushed a commit with a syntax error. CI ran the tests and failed, and the Deploy workflow is only triggered when CI succeeds on `main`, so Deploy never started. Nothing was sent to app-vm, and `/health` kept answering OK the whole time. I fixed the problem with `git revert` and a push, and CI and Deploy ran green again.

The test gate in front of Deploy is exactly the change that stops broken code from reaching app-vm. There is still one weakness: if the tests pass but a step on the server fails (for example `composer install` or a migration), the server can be left half-updated. To make it safer, I would build each release in a new folder and switch a symlink only after composer, migrations and a health check on the new release succeed. I would also add more tests.

**3. Why is it important to store the backups on app-vm and not on db-vm? What happens to them if app-vm dies?**

If the backups sat on db-vm, then losing db-vm would destroy both the live database and every backup of it. Keeping them on a different server means one failure can't take out both. The drill proved this: with db-vm down, I rebuilt the app using only the backups on app-vm.

If app-vm dies, the backups on it are lost with it. The live database on db-vm would still be fine, but it would have no backups until I set up new ones. The way to reduce that risk is a third copy somewhere outside both servers, such as my laptop or an S3 bucket, or regular EBS snapshots. I didn't do that, and I list it as a limitation below.

**4. With my backup schedule, what is the most data I could lose?**

My backups run every hour, at minute 5, and each one takes about a second. So in the worst case, I would lose a little more than an hour of changes: everything written after the most recent successful backup. If a backup fails, the gap grows until the next success, which is why failures are logged and temporary files are cleaned up.

**5. Why should I test restoring a backup, and how often?**

A backup that has never been restored is only a hope. It can be empty, truncated, or missing tables. I learned this myself in the drill: my first dump was empty and I only noticed when the import found no tables. A restore test also proves I know the procedure before I'm under pressure. I would test a restore at least once a month, and again after any change to the backup script, the MySQL version or the database layout. A quick check on every run is also built into the script, because it refuses to publish a file that is empty or fails `gzip -t`.

**6. When I type my domain in the browser, how does my laptop find app-vm's IP address? And how does the web server on app-vm know which site to show?**

My laptop asks its DNS resolver for `laravelapp-abbasshafi.duckdns.org`. The resolver asks DuckDNS's name servers, which hold my A record and answer with app-vm's public IP address. (For a local test domain, the same answer would come from the hosts file.) The browser then connects to that IP on port 80 and sends an HTTP request that includes a `Host:` header with the domain name.

nginx on app-vm compares the `Host` header with the `server_name` of each server block and serves the block that matches. That's how the same server can host several sites on one IP. If the name matches nothing, which is what happens when someone uses the bare IP, nginx uses the `default_server` block. I made that block return 444, which closes the connection with no page.

---

## What's in the repository

```
.github/workflows/ci.yml        tests on push and pull request to main
.github/workflows/deploy.yml    deploys after CI passes, or when started by hand
scripts/cleanup-logs.sh         nightly Laravel log cleanup (Task 5)
scripts/laravel-db-backup.sh    hourly database backup (Task 4), no passwords inside
routes/web.php                  app routes: /, /health, /db-test, /users and the update pages
screenshots/                    proof images, named T<task>-S<number>.png
README.md, report.md            this report
```
