# GitHub Links Update Summary

## Repository Information

- **GitHub Username**: `hioTEC`
- **Repository Name**: `XUI-SOLO`
- **Repository URL**: https://github.com/hioTEC/XUI-SOLO
- **Contact Email**: security@hiotec.dev / dev@hiotec.dev

## Updated Files

### Documentation Files

1. **README.md**
   - ✅ Updated all `github.com/your-repo/xray-cluster` → `github.com/hioTEC/XUI-SOLO`
   - ✅ Updated all `raw.githubusercontent.com` URLs
   - ✅ Updated GitHub Issues links
   - ✅ Updated GitHub Discussions links
   - ✅ Updated contact email to `security@hiotec.dev`
   - ✅ Updated directory references from `xray-cluster` to `XUI-SOLO`

2. **CHANGELOG.md**
   - ✅ Updated installation script URLs
   - ✅ Updated git clone commands

3. **QUICKSTART.md**
   - ✅ Updated git clone commands (2 occurrences)
   - ✅ Updated repository references

4. **DEPLOYMENT.md**
   - ✅ Updated wget script download URL
   - ✅ Updated contact email to `security@hiotec.dev`

5. **DEVELOPMENT.md**
   - ✅ Updated git clone command
   - ✅ Updated contact email to `dev@hiotec.dev`

6. **PROJECT_STATUS.md**
   - ✅ Updated contact email to `security@hiotec.dev`

### Template Files

7. **master/templates/nodes.html**
   - ✅ Updated installation script URL in UI

8. **master/templates/add_node.html**
   - ✅ Updated installation script URL in UI

## Installation Commands (Updated)

### SOLO Mode
```bash
curl -fsSL https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh | sudo bash -s -- --solo
```

### Master Node
```bash
curl -fsSL https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh | sudo bash -s -- --master
```

### Worker Node
```bash
curl -fsSL https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh | sudo bash -s -- --node
```

### Git Clone
```bash
git clone https://github.com/hioTEC/XUI-SOLO.git
cd XUI-SOLO
```

## Contact Information

- **Issues**: https://github.com/hioTEC/XUI-SOLO/issues
- **Discussions**: https://github.com/hioTEC/XUI-SOLO/discussions
- **Security**: security@hiotec.dev
- **Development**: dev@hiotec.dev

## Notes

- All installation paths on the server (`/opt/xray-cluster/`) remain unchanged as they are local filesystem paths
- Database names and internal references remain as `xray_cluster` for consistency
- Only external-facing URLs and contact information were updated

## Verification

To verify all links are correct, search for:
- ❌ `your-repo` - Should return no results
- ❌ `@example.com` - Should return no results (except in example configs)
- ✅ `hioTEC/XUI-SOLO` - Should be present in all documentation
- ✅ `@hiotec.dev` - Should be present in contact sections

---

**Update Date**: 2024-12-06
**Status**: ✅ Complete
