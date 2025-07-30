# Request Sudo Access - Examples and Use Cases

## Usage Examples

### 1. Docker Access (Most Common)
```bash
./request-sudo-access.sh docker 2h
```
**Grants:** Docker daemon access for container operations
**Use cases:** 
- Building Docker images
- Running containers for development
- Docker compose operations
**Commands enabled:**
- `sudo docker build .`
- `sudo docker run -it ubuntu`
- `sudo docker-compose up`

### 2. Service Management
```bash
./request-sudo-access.sh services 1h
```
**Grants:** System service control
**Use cases:**
- Restarting web servers during development
- Managing database services
- Starting/stopping development services
**Commands enabled:**
- `sudo systemctl restart nginx`
- `sudo service postgresql start`
- `sudo systemctl status mysql`

### 3. Network Configuration
```bash
./request-sudo-access.sh network 30m
```
**Grants:** Network troubleshooting and configuration
**Use cases:**
- Network debugging
- Firewall rule inspection
- Traffic monitoring
**Commands enabled:**
- `sudo iptables -L`
- `sudo tcpdump -i eth0`
- `sudo netstat -tulpn`

### 4. System Administration
```bash
./request-sudo-access.sh system 1h
```
**Grants:** System-level operations
**Use cases:**
- Mounting storage devices
- System configuration changes
- Hardware diagnostics
**Commands enabled:**
- `sudo mount /dev/sdb1 /mnt/data`
- `sudo fdisk -l`
- `sudo lsof -i`

### 5. Temporary Full Admin (Emergency Only)
```bash
./request-sudo-access.sh temp-admin 15m
```
**Grants:** Full sudo access (like original configuration)
**Use cases:**
- Emergency system recovery
- Complex multi-step operations
- When other options don't work
**Warning:** Requires explicit confirmation

## How the Script Creates Temporary Access

### Example: Docker Access Request

1. **User runs command:**
   ```bash
   ./request-sudo-access.sh docker 2h
   ```

2. **Script creates temporary sudoers file:**
   ```bash
   # File: /etc/sudoers.d/temp-1703123456
   # Temporary sudo access - expires in 2h
   # Created: Mon Dec 21 10:30:00 2023
   coder ALL=(ALL) NOPASSWD: /usr/bin/docker, /usr/bin/docker-compose
   ```

3. **Automatic cleanup scheduled:**
   ```bash
   # Command scheduled to run in 2 hours:
   sudo rm -f /etc/sudoers.d/temp-1703123456
   ```

4. **User can now run Docker commands:**
   ```bash
   sudo docker ps          # ✅ Works
   sudo docker build .     # ✅ Works
   sudo systemctl restart nginx  # ❌ Still blocked
   ```

## Security Features

### Time-Limited Access
- **Automatic expiration** - permissions automatically removed
- **No manual cleanup needed** - uses system scheduler
- **Default duration limits** - prevents indefinite access

### Minimal Permissions
- **Task-specific access** - only grants what's needed
- **No privilege creep** - doesn't expand existing permissions
- **Audit trail** - creates timestamped files with purpose

### User Control
- **Self-service** - no admin intervention needed
- **Explicit consent** - user must choose permission type
- **Confirmation required** - for high-privilege requests

## Real-World Usage Scenarios

### Scenario 1: ML Engineer Building Custom Container
```bash
# Need to build a custom ML image with specific CUDA libraries
./request-sudo-access.sh docker 1h

# Now can build the image
sudo docker build -t my-ml-image:latest .
sudo docker run --gpus all my-ml-image:latest python train.py

# Access automatically expires in 1 hour
```

### Scenario 2: Data Scientist Debugging Network Issues
```bash
# Connection issues with data lake, need to debug
./request-sudo-access.sh network 30m

# Check network connectivity
sudo tcpdump -i eth0 port 443
sudo netstat -an | grep lakefs

# Access expires in 30 minutes
```

### Scenario 3: DevOps Engineer Setting Up Services
```bash
# Need to configure nginx for model serving
./request-sudo-access.sh services 2h

# Configure and start services
sudo systemctl enable nginx
sudo systemctl start nginx
sudo systemctl restart mlflow-server

# Access expires in 2 hours
```

## Monitoring and Auditing

### Check Current Permissions
```bash
sudo -l  # Shows all current sudo permissions
```

### View Temporary Access Files
```bash
ls -la /etc/sudoers.d/temp-*  # Shows active temporary permissions
```

### Check Scheduled Cleanup
```bash
at -l  # Shows scheduled cleanup jobs
```

### View Sudo Usage Logs
```bash
journalctl -u sudo  # System logs of sudo usage
tail -f /var/log/sudo.log  # Detailed sudo audit log
```