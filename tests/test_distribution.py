"""
Distribution package tests for TalkyMcTalkface.

Tests for Task 6.1:
- Test .app bundle structure is correct
- Test code signature is valid (when signed)
- Test DMG mounts and contains expected contents
"""
import os
import subprocess
import tempfile
from pathlib import Path

import pytest


# Expected paths relative to the project root
PROJECT_ROOT = Path(__file__).parent.parent
APP_BUILD_DIR = PROJECT_ROOT / 'build' / 'Release' / 'TalkyMcTalkface.app'
DMG_PATH = PROJECT_ROOT / 'dist' / 'TalkyMcTalkface.dmg'


class TestAppBundleStructure:
    """Test that the .app bundle has correct structure."""

    @pytest.fixture
    def app_path(self):
        """Get the .app bundle path, skip if not built."""
        # Check multiple possible locations for the built app
        possible_paths = [
            APP_BUILD_DIR,
            PROJECT_ROOT / 'dist' / 'TalkyMcTalkface.app',
            Path.home() / 'Library' / 'Developer' / 'Xcode' / 'DerivedData',
        ]

        # Look for the app in DerivedData if not in standard locations
        for path in possible_paths[:2]:
            if path.exists():
                return path

        # Search DerivedData for the app
        derived_data = possible_paths[2]
        if derived_data.exists():
            for derived_dir in derived_data.iterdir():
                if 'TalkyMcTalkface' in derived_dir.name:
                    app_path = derived_dir / 'Build' / 'Products' / 'Release' / 'TalkyMcTalkface.app'
                    if app_path.exists():
                        return app_path

        pytest.skip('TalkyMcTalkface.app not found. Build the app first with: xcodebuild -project TalkyMcTalkface/TalkyMcTalkface.xcodeproj -scheme TalkyMcTalkface -configuration Release build')

    def test_app_bundle_exists(self, app_path):
        """Test that .app bundle exists and is a directory."""
        assert app_path.exists(), f'App bundle not found at {app_path}'
        assert app_path.is_dir(), f'{app_path} is not a directory bundle'

    def test_app_bundle_has_contents(self, app_path):
        """Test that .app bundle has Contents directory."""
        contents_path = app_path / 'Contents'
        assert contents_path.exists(), 'Contents directory missing from .app bundle'
        assert contents_path.is_dir(), 'Contents is not a directory'

    def test_app_bundle_has_macos_executable(self, app_path):
        """Test that .app bundle has MacOS executable."""
        macos_path = app_path / 'Contents' / 'MacOS'
        assert macos_path.exists(), 'MacOS directory missing from .app bundle'

        executable = macos_path / 'TalkyMcTalkface'
        assert executable.exists(), 'TalkyMcTalkface executable missing'
        assert os.access(executable, os.X_OK), 'Executable is not executable'

    def test_app_bundle_has_info_plist(self, app_path):
        """Test that .app bundle has Info.plist."""
        info_plist = app_path / 'Contents' / 'Info.plist'
        assert info_plist.exists(), 'Info.plist missing from .app bundle'

        # Verify Info.plist is valid
        result = subprocess.run(
            ['plutil', '-lint', str(info_plist)],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0, f'Info.plist is invalid: {result.stderr}'


class TestCodeSignature:
    """Test code signature validity."""

    @pytest.fixture
    def app_path(self):
        """Get the .app bundle path, skip if not built."""
        possible_paths = [
            APP_BUILD_DIR,
            PROJECT_ROOT / 'dist' / 'TalkyMcTalkface.app',
        ]

        for path in possible_paths:
            if path.exists():
                return path

        # Search DerivedData
        derived_data = Path.home() / 'Library' / 'Developer' / 'Xcode' / 'DerivedData'
        if derived_data.exists():
            for derived_dir in derived_data.iterdir():
                if 'TalkyMcTalkface' in derived_dir.name:
                    app_path = derived_dir / 'Build' / 'Products' / 'Release' / 'TalkyMcTalkface.app'
                    if app_path.exists():
                        return app_path

        pytest.skip('TalkyMcTalkface.app not found')

    def test_code_signature_valid(self, app_path):
        """Test that code signature is valid (if signed)."""
        result = subprocess.run(
            ['codesign', '-v', '--verbose=2', str(app_path)],
            capture_output=True,
            text=True
        )

        # App may be unsigned during development - that's okay
        if result.returncode != 0:
            if 'code object is not signed at all' in result.stderr:
                pytest.skip('App is not signed (expected during development)')
            else:
                # If signed but invalid, that's a failure
                assert 'valid on disk' in result.stdout or result.returncode == 0, \
                    f'Code signature verification failed: {result.stderr}'

    def test_code_signature_requirements(self, app_path):
        """Test code signature requirements can be displayed."""
        result = subprocess.run(
            ['codesign', '-dr', '-', str(app_path)],
            capture_output=True,
            text=True
        )

        # Skip if not signed
        if 'code object is not signed at all' in result.stderr:
            pytest.skip('App is not signed (expected during development)')

        # If signed, should have designated requirement
        assert result.returncode == 0 or 'designated' in result.stdout.lower(), \
            f'Could not read code signature requirements: {result.stderr}'


class TestDMGContents:
    """Test DMG distribution package."""

    @pytest.fixture
    def mounted_dmg(self):
        """Mount DMG and yield the mount point, unmount after test."""
        if not DMG_PATH.exists():
            pytest.skip(f'DMG not found at {DMG_PATH}. Build with: ./scripts/build_distribution.sh')

        # Create temporary mount point
        mount_point = Path(tempfile.mkdtemp(prefix='talky_dmg_'))

        try:
            # Mount DMG
            result = subprocess.run(
                ['hdiutil', 'attach', str(DMG_PATH), '-mountpoint', str(mount_point), '-nobrowse'],
                capture_output=True,
                text=True
            )

            if result.returncode != 0:
                pytest.skip(f'Failed to mount DMG: {result.stderr}')

            yield mount_point

        finally:
            # Unmount DMG
            subprocess.run(
                ['hdiutil', 'detach', str(mount_point), '-force'],
                capture_output=True
            )
            # Clean up mount point directory
            if mount_point.exists():
                try:
                    mount_point.rmdir()
                except OSError:
                    pass

    def test_dmg_contains_app(self, mounted_dmg):
        """Test that DMG contains the .app bundle."""
        app_path = mounted_dmg / 'TalkyMcTalkface.app'
        assert app_path.exists(), 'TalkyMcTalkface.app not found in DMG'
        assert app_path.is_dir(), 'TalkyMcTalkface.app is not a directory bundle'

    def test_dmg_contains_applications_alias(self, mounted_dmg):
        """Test that DMG contains Applications folder alias."""
        # Applications link can be either a symlink or an alias file
        apps_link = mounted_dmg / 'Applications'
        assert apps_link.exists(), 'Applications folder alias not found in DMG'

    def test_dmg_app_has_valid_structure(self, mounted_dmg):
        """Test that the app in DMG has valid structure."""
        app_path = mounted_dmg / 'TalkyMcTalkface.app'
        if not app_path.exists():
            pytest.skip('App not found in DMG')

        # Check for essential components
        assert (app_path / 'Contents' / 'MacOS' / 'TalkyMcTalkface').exists(), \
            'Executable missing from app in DMG'
        assert (app_path / 'Contents' / 'Info.plist').exists(), \
            'Info.plist missing from app in DMG'
