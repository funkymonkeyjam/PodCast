"""Qualification safety limits and truthful reporting."""

import wave
from pathlib import Path

import numpy as np
import pytest

from scripts.native_probe import run_probe, write_probe_wav


def test_quiet_wave_and_stereo_markers(tmp_path):
    path = tmp_path / "quiet.wav"
    markers = write_probe_wav(path, 5)
    with wave.open(str(path)) as wav:
        assert wav.getframerate() == 44100
        assert wav.getnframes() == 5 * 44100
        pcm = np.frombuffer(wav.readframes(wav.getnframes()), dtype="<i2").reshape(-1, 2)
    assert np.max(np.abs(pcm)) <= 1639
    assert markers[0]["channel"] == "left"
    assert markers[1]["channel"] == "right"
    assert np.max(np.abs(pcm[15000:25000, 1])) == 0
    assert np.max(np.abs(pcm[60000:70000, 0])) == 0


@pytest.mark.parametrize("rate", [44100, 48000])
def test_probe_wav_follows_selected_sample_rate(tmp_path, rate):
    path = tmp_path / "quiet.wav"
    write_probe_wav(path, 1, rate)
    with wave.open(str(path)) as wav:
        assert wav.getframerate() == rate
        assert wav.getnframes() == rate


@pytest.mark.parametrize("rate", [44100, 48000])
@pytest.mark.parametrize("peak", [0.001, 0.05, 0.5])
def test_selected_synthetic_peak_matches_actual_pcm(tmp_path, rate, peak):
    path = tmp_path / "synthetic.wav"
    write_probe_wav(path, 1, rate, peak)
    with wave.open(str(path)) as wav:
        assert wav.getnchannels() == 2
        assert wav.getsampwidth() == 2
        pcm = np.frombuffer(wav.readframes(wav.getnframes()), dtype="<i2").reshape(-1, 2)
    assert np.max(np.abs(pcm[:, 0])) == pytest.approx(32767 * peak, abs=1)
    assert np.max(np.abs(pcm[:, 1])) == 0
    assert np.max(np.abs(pcm[: round(rate * 0.25)])) == 0
    assert np.max(np.abs(pcm[round(rate * 0.75) :])) == 0


@pytest.mark.parametrize("peak", [0, -0.1, 0.500001, float("nan"), float("inf")])
def test_unsafe_synthetic_peak_does_not_create_wave(tmp_path, peak):
    path = tmp_path / "must-not-exist.wav"
    with pytest.raises(ValueError, match="peak"):
        write_probe_wav(path, 1, peak=peak)
    assert not path.exists()


@pytest.mark.parametrize("peak", [0, -0.1, 0.500001, float("nan"), float("inf")])
async def test_unsafe_synthetic_peak_rejected_before_engine_lookup(monkeypatch, peak):
    monkeypatch.setattr(
        "scripts.native_probe.engine_path", lambda: pytest.fail("Engine lookup preceded peak validation")
    )
    with pytest.raises(ValueError, match="peak"):
        await run_probe(["127.0.0.1"], 1, 0.1, signal_peak=peak)


@pytest.mark.parametrize(
    "overrides",
    [
        {"hosts": []},
        {"hosts": ["127.0.0.1", "127.0.0.2"]},
        {"source": "loopback"},
        {"record_mic_path": Path("must-not-record.wav")},
        {"group_id": ""},
    ],
)
async def test_capture_recording_and_multiple_receivers_rejected_before_engine(monkeypatch, overrides):
    monkeypatch.setattr(
        "scripts.native_probe.engine_path", lambda: pytest.fail("Engine lookup preceded safety validation")
    )
    options = {"hosts": ["127.0.0.1"], "duration": 1, "gain": 0.1, **overrides}
    with pytest.raises(ValueError, match="one receiver and synthetic WAV"):
        await run_probe(**options)


@pytest.mark.parametrize("duration", [0, -1, 5.1, float("nan")])
def test_invalid_duration_rejected_before_recording(tmp_path, duration):
    with pytest.raises(ValueError):
        write_probe_wav(tmp_path / "must-not-exist.wav", duration)
    assert not (tmp_path / "must-not-exist.wav").exists()


@pytest.mark.parametrize("rate", [44101, 48001, 96000])
def test_invalid_rate_rejected_before_recording(tmp_path, rate):
    with pytest.raises(ValueError):
        write_probe_wav(tmp_path / "must-not-exist.wav", 1, rate)
    assert not (tmp_path / "must-not-exist.wav").exists()


async def test_unsafe_gain_rejected_before_starting_engine():
    with pytest.raises(ValueError):
        await run_probe(["127.0.0.1"], 5, 0.2)


@pytest.mark.parametrize("rate", [44101, 48001, 96000])
async def test_unsafe_sample_rate_rejected_before_starting_engine(rate):
    with pytest.raises(ValueError):
        await run_probe(["127.0.0.1"], 5, 0.1, sample_rate=rate)
