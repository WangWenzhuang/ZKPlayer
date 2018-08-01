//
//  ZKPlayer.swift
//  ZKPlayer
//
//  Created by 王文壮 on 2018/7/4.
//  Copyright © 2018年 王文壮. All rights reserved.
//

import AVKit
import Kingfisher

open class ZKPlayer: UIView {
    @objc convenience init() {
        self.init(frame: CGRect.zero)
    }
    
    @objc convenience init(frame: CGRect, url: URL, title: String, thumbnailUrl: URL? = nil) {
        self.init(frame: frame)
        videoUrl = url
        self.title = title
        self.thumbnailUrl = thumbnailUrl
    }
    
    @objc override init(frame: CGRect) {
        super.init(frame: frame)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appBecomeActive),
            name: .UIApplicationDidBecomeActive, object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: .UIApplicationWillResignActive,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playFinished),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
        loadView()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        // 移除所有监听
        NotificationCenter.default.removeObserver(self, name: .UIApplicationDidBecomeActive, object: nil)
        NotificationCenter.default.removeObserver(self, name: .UIApplicationWillResignActive, object: nil)
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        removePlayerItemObserver(player?.currentItem)
    }
    
    /// 视频路径
    @objc public var videoUrl: URL!
    /// 视频标题
    @objc public var title: String {
        get {
            return titleLabel.text ?? ""
        } set {
            titleLabel.text = newValue
        }
    }
    /// 缩略图 URL
    @objc public var thumbnailUrl: URL? = nil
    /// 播放完成回调
    @objc public var finished: ((_ second: TimeInterval) -> Void)? = nil
    
    private static let bundle = Bundle(url: Bundle(for: ZKPlayer.self).url(forResource: "ZKPlayer", withExtension: "bundle")!)
    /// 全屏模式下返回按钮图片（可重写）
    @objc open var backButtonImage: UIImage? {
        return UIImage(contentsOfFile: (ZKPlayer.bundle?.path(forResource: "player_back@3x", ofType: "png"))!)
    }
    /// 全屏模式下播放按钮图片（可重写）
    @objc open var playButtonImage: UIImage? {
        return UIImage(contentsOfFile: (ZKPlayer.bundle?.path(forResource: "player_play@3x", ofType: "png"))!)
    }
    /// 全屏模式下暂停按钮图片（可重写）
    @objc open var pauseButtonImage: UIImage? {
        return UIImage(contentsOfFile: (ZKPlayer.bundle?.path(forResource: "player_pause@3x", ofType: "png"))!)
    }
    /// 非全屏模式下播放按钮图片（可重写）
    @objc open var bigPlayButtonImage: UIImage? {
        return UIImage(contentsOfFile: (ZKPlayer.bundle?.path(forResource: "player_bigPlay@3x", ofType: "png"))!)
    }
    /// 非全屏模式下暂停按钮图片（可重写）
    @objc open var bigPauseButtonImage: UIImage? {
        return UIImage(contentsOfFile: (ZKPlayer.bundle?.path(forResource: "player_bigPause@3x", ofType: "png"))!)
    }
    /// 全屏按钮图片（可重写）
    @objc open var fullScreenButtonImage: UIImage? {
        return UIImage(contentsOfFile: (ZKPlayer.bundle?.path(forResource: "player_fullScreen@3x", ofType: "png"))!)
    }
    /// 视频标题字体（可重写）
    @objc open var titleFont: UIFont {
        return UIFont.systemFont(ofSize: 15)
    }
    /// 时间进度条滑块左边颜色（可重写）
    @objc open var timeSliderMinimumTrackTintColor: UIColor {
        return UIColor(red: 202 / 255.0, green: 51 / 255.0, blue: 54 / 255.0, alpha: 1)
    }
    /// 时间进度条滑块图片（可重写）
    @objc open var timeSliderThumbImage: UIImage? {
        return UIImage(named: "player_silder")
    }
    
    /// 程序后台记录当前播放时间
    private var backgroundTime: CMTime?
    /// 是否全屏
    private var isLandscape: Bool {
        return  UIApplication.shared.statusBarOrientation.isLandscape
    }
    /// 是否正在播放
    private lazy var isPlaying = false
    /// 进度条是否在拖动
    private lazy var isTimeSliderDraging = false
    /// 是否隐藏标题栏和控制栏
    private lazy var isHideHaderAndControl = false
    /// 防止 AVPlayerLayer 重复点击
    private lazy var isTapEnabled = true
    
    /// AVPlayerLayer
    private lazy var playerLayer = AVPlayerLayer()
    /// AVPlayer
    private var player: AVPlayer?
    /// 缩略图
    private var thumbnailView = UIImageView()
    /// 显示加载指示器
    private lazy var activityView: UIActivityIndicatorView = {
        $0.activityIndicatorViewStyle = .white
        $0.color = .white
        $0.sizeToFit()
        $0.isHidden = true
        return $0
    }(UIActivityIndicatorView())
    /// 全屏模式下返回按钮
    private lazy var backButton = UIButton()
    /// 视频标题
    private lazy var titleLabel: UILabel = {
        $0.font = titleFont
        $0.textColor = .white
        return $0
    }(UILabel())
    /// 头（视频标题和返回按钮）
    private lazy var headerView = UIView()
    
    /// 非全屏模式下播放/暂停按钮
    private lazy var bigPlayButton = UIButton()
    /// 全屏模式下播放/暂停按钮
    private lazy var playButton = UIButton()
    /// 全屏按钮
    private lazy var fullScreenButton = UIButton()
    /// 视频当前时间
    private lazy var currentTimeLalbel: UILabel = {
        $0.text = "00:00"
        $0.frame.size.width = 41
        $0.font = UIFont.systemFont(ofSize: 12)
        $0.textAlignment = .center
        $0.textColor = .white
        return $0
    }(UILabel())
    /// 视频总时间
    private lazy var totalTimeLalbel: UILabel = {
        $0.text = "00:00"
        $0.frame.size.width = 41
        $0.font = UIFont.systemFont(ofSize: 12)
        $0.textAlignment = .center
        $0.textColor = .white
        return $0
    }(UILabel())
    /// 进度条
    private lazy var timeSlider = UISlider()
    /// 视频控制面板
    private lazy var controlView = UIView()
    
    /// 重新布局界面
    override open func layoutSubviews() {
        super.layoutSubviews()
        // Player
        playerLayer.frame.size = frame.size
        // thumbnailView
        thumbnailView.frame.size = frame.size
        // activityView
        activityView.frame.origin = CGPoint(
            x: (frame.width - activityView.frame.width) / 2,
            y: (frame.height - activityView.frame.height) / 2
        )
        // Header
        if isLandscape {
            headerView.frame = CGRect(x: 0, y: 0, width: frame.width, height: 40)
            let backButtonWidth = backButton.frame.width > headerView.frame.height ? headerView.frame.height : backButton.frame.width
            let y = (headerView.frame.height - backButtonWidth) / 2
            backButton.isHidden = false
            backButton.frame = CGRect(x: 5, y: y, width: backButtonWidth, height: backButtonWidth)
            titleLabel.frame = CGRect(
                x: backButton.frame.origin.x + backButtonWidth + 5,
                y: 0,
                width: frame.width - backButton.frame.origin.x - backButtonWidth - 15,
                height: headerView.frame.height
            )
        } else {
            headerView.frame = CGRect(x: 0, y: 0, width: frame.width, height: 30)
            backButton.isHidden = true
            titleLabel.frame = CGRect(x: 15, y: 0, width: frame.width - 30, height: headerView.frame.height)
        }
        // bigPlayButton
        if isLandscape {
            bigPlayButton.isHidden = true
        } else {
            bigPlayButton.isHidden = isHideHaderAndControl
        }
        bigPlayButton.frame.origin = CGPoint(
            x: (frame.width - bigPlayButton.frame.width) / 2,
            y: (frame.height - bigPlayButton.frame.height) / 2
        )
        // Control
        let controlViewHeight = playButton.frame.height + 20
        controlView.frame = CGRect(x: 0, y: frame.height - controlViewHeight, width: frame.width, height: controlViewHeight)
        // playButton
        if isLandscape {
            playButton.isHidden = false
        } else {
            playButton.isHidden = true
        }
        let playButtonWidth = playButton.frame.width > controlView.frame.height ? controlView.frame.height : playButton.frame.width
        let playButtonY = (controlView.frame.height - playButtonWidth) / 2
        playButton.frame = CGRect(x: 15, y: playButtonY, width: playButtonWidth, height: playButtonWidth)
        // currentTimeLalbel
        let currentTimeLalbelX = isLandscape ? playButton.frame.origin.x + playButton.frame.width + 2 : 15
        currentTimeLalbel.frame = CGRect(
            x: currentTimeLalbelX,
            y: 0,
            width: currentTimeLalbel.frame.width,
            height: controlView.frame.height
        )
        // totalTimeLalbel
        var totalTimeLalbelX = frame.width - 15 - totalTimeLalbel.frame.width
        if !isLandscape {
            totalTimeLalbelX = frame.width - 15 - totalTimeLalbel.frame.width - fullScreenButton.frame.width - 5
        }
        totalTimeLalbel.frame = CGRect(
            x: totalTimeLalbelX,
            y: 0,
            width: totalTimeLalbel.frame.width,
            height: controlView.frame.height
        )
        // timeSlider
        var timeSliderWidth: CGFloat = 0
        if isLandscape {
            timeSliderWidth = frame.width - currentTimeLalbel.frame.origin.x - currentTimeLalbel.frame.width - totalTimeLalbel.frame.width - 25
        } else {
            timeSliderWidth = frame.width - currentTimeLalbel.frame.origin.x - currentTimeLalbel.frame.width - totalTimeLalbel.frame.width - fullScreenButton.frame.width - 30
        }
        timeSlider.frame = CGRect(
            x: currentTimeLalbel.frame.origin.x + currentTimeLalbel.frame.width + 5,
            y: 0,
            width: timeSliderWidth,
            height: controlView.frame.height
        )
        // fullScreenButton
        if isLandscape {
            fullScreenButton.isHidden = true
        } else {
            fullScreenButton.isHidden = false
            var fullScreenButtonWidth = fullScreenButton.frame.width
            if fullScreenButton.frame.width > controlView.frame.height {
                fullScreenButtonWidth = controlView.frame.height
            }
            let fullScreenButtonY = (controlView.frame.height - fullScreenButtonWidth) / 2
            fullScreenButton.frame = CGRect(
                x: frame.width - 15 - fullScreenButtonWidth,
                y: fullScreenButtonY,
                width: fullScreenButtonWidth,
                height: fullScreenButtonWidth
            )
        }
    }
}
// MARK: 公共方法
extension ZKPlayer {
    /// 播放视频
    @objc public func play() {
        thumbnailView.removeFromSuperview()
        isPlaying = true
        refreshPlayButton()
        timeSlider.value = 0
        bigPlayButton.isHidden = true
        showLoading()
        totalTimeLalbel.text = "00:00"
        currentTimeLalbel.text = "00:00"
        let playerItem = AVPlayerItem(url: videoUrl)
        playerItem.addObserver(self, forKeyPath: "status", options: .new, context: nil)
        playerItem.addObserver(self, forKeyPath: "loadedTimeRanges", options: .new, context: nil)
        playerItem.addObserver(self, forKeyPath: "playbackBufferEmpty", options: .new, context: nil)
        playerItem.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: .new, context: nil)
        player = AVPlayer(playerItem: playerItem)
        playerLayer.player = player
        player?.play()
    }
    /// 暂停视频
    @objc public func pause() {
        isPlaying = false
        refreshPlayButton()
        player?.pause()
    }
}
// MARK: 监听 App 后台/前台
extension ZKPlayer {
    /// App 后台，如果正在播放视频，记录播放时间并暂停
    @objc private func appWillResignActive() {
        if let player = player {
            player.pause()
            backgroundTime = player.currentTime()
        }
    }
    /// 激活 App，继续播放
    @objc private func appBecomeActive() {
        if isPlaying, let player = player, let time = backgroundTime {
            player.seek(to: time, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero) {
                if $0 {
                    player.play()
                }
            }
        }
    }
}
// MARK: 视频监听
extension ZKPlayer {
    /// 视频播放完成
    @objc private func playFinished() {
        if let player = player {
            player.pause()
            isPlaying = false
            refreshPlayButton()
            removePlayerItemObserver(player.currentItem)
            self.player = nil
            showHeaderAndControl()
            if let block = finished {
                block(TimeInterval(timeSlider.maximumValue))
            }
        }
    }
    /// 视频播放监听
    ///
    /// - Parameters:
    ///   - forKeyPath: forKeyPath
    ///   - of: of
    ///   - change: change
    ///   - context: context
    override open func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let playerItem = object as? AVPlayerItem, let player = player else { return }
        let duration = playerItem.duration
        if keyPath == "status" {                            // 播放器状态
            hideLoading()
            switch playerItem.status {
            case .readyToPlay:          // 准备好了，可以播放
                let totalSecond = Float(duration.value) / Float(duration.timescale)
                timeSlider.maximumValue = totalSecond
                totalTimeLalbel.text = convertTime(second: totalSecond)
                player.addPeriodicTimeObserver(forInterval: CMTimeMake(1, 1), queue: nil) {
                    let currentSecond = Float($0.value) / Float($0.timescale)
                    if !self.isTimeSliderDraging {
                        self.timeSlider.value = currentSecond
                    }
                    self.currentTimeLalbel.text = self.convertTime(second: currentSecond)
                }
            case .failed,
                 .unknown:              // 播放失败
                isPlaying = false
                refreshPlayButton()
                player.pause()
            }
        } else if keyPath == "loadedTimeRanges" {           // 播放器下载进度
            let loadedTimeRanges = playerItem.loadedTimeRanges
            if let timeRange = loadedTimeRanges.first?.timeRangeValue {
                let startSecondes = CMTimeGetSeconds(timeRange.start)
                let durationSeconds = CMTimeGetSeconds(timeRange.duration)
                let buffer = startSecondes + durationSeconds //缓冲总长度
                let totalDuration = CMTimeGetSeconds(duration)
                print(String(format: "缓存进度：%.0f%%", buffer / Double(totalDuration) * 100))
            }
        } else if keyPath == "playbackBufferEmpty" {        // 播放器在缓冲数据的状态
            showLoading()
        } else if keyPath == "playbackLikelyToKeepUp" {     // 播放器在缓冲数据的状态
            hideLoading()
            if isPlaying {
                player.play()
            }
        }
    }
}
// MARK: 事件
extension ZKPlayer {
    /// 显示头和视频控制面板，如果处于播放状态，3秒后自动隐藏头和视频控制面板
    @objc private func showAndHideHaderAndControlAction() {
        if isTapEnabled {
            if isHideHaderAndControl {
                showHeaderAndControl()
            } else {
                hideHeaderAndControl()
            }
        }
    }
    /// 进度条开始拖拽
    @objc private func timeSliderTouchDragInsideAction() {
        isTimeSliderDraging = true
        
    }
    /// 进度条值更改，在拖拽之后会出发一次
    /// - Parameters:
    ///   - slider: UISlider
    @objc private func timeSliderChangeAction(slider: UISlider) {
        if let player = player {
            let seconds = slider.value
            let time = CMTimeMakeWithSeconds(Float64(seconds), 1)
            player.seek(to: time) {_ in
                self.isTimeSliderDraging = false
            }
        }
    }
    /// 播放按钮事件
    @objc private func playAction() {
        if isPlaying {
            pause()
        } else {
            if let player = player {
                isPlaying = !isPlaying
                refreshPlayButton()
                player.play()
            } else {
                play()
            }
            autoHideHeaderAndControl()
        }
    }
    /// 全屏按钮事件，横屏
    @objc private func fullScreenAction() {
        UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
    }
    /// 返回按钮事件，切回竖屏
    @objc private func backAction() {
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
    }
}
// MARK: 私有方法
extension ZKPlayer {
    /// 加载界面
    private func loadView() {
        backgroundColor = .black
        layer.addSublayer(playerLayer)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(showAndHideHaderAndControlAction)))
        if let thumbnailUrl = thumbnailUrl {
            addSubview(thumbnailView)
            thumbnailView.kf.setImage(with: thumbnailUrl)
        }
        // backButton
        backButton.setImage(backButtonImage, for: .normal)
        backButton.addTarget(self, action: #selector(backAction), for: .touchUpInside)
        backButton.sizeToFit()
        // headerView
        headerView.addSubview(backButton)
        headerView.addSubview(titleLabel)
        addSubview(headerView)
        // bigPlayButton
        bigPlayButton.setImage(bigPlayButtonImage, for: .normal)
        bigPlayButton.addTarget(self, action: #selector(playAction), for: .touchUpInside)
        bigPlayButton.sizeToFit()
        addSubview(bigPlayButton)
        // activityView
        addSubview(activityView)
        // playButton
        playButton.setImage(playButtonImage, for: .normal)
        playButton.addTarget(self, action: #selector(playAction), for: .touchUpInside)
        playButton.sizeToFit()
        // fullScreenButton
        fullScreenButton.setImage(fullScreenButtonImage, for: .normal)
        fullScreenButton.addTarget(self, action: #selector(fullScreenAction), for: .touchUpInside)
        fullScreenButton.sizeToFit()
        // timeSlider
        timeSlider.backgroundColor = .clear
        timeSlider.isContinuous = false
        timeSlider.minimumTrackTintColor = timeSliderMinimumTrackTintColor
        timeSlider.setThumbImage(timeSliderThumbImage, for: .normal)
        timeSlider.addTarget(self, action: #selector(timeSliderChangeAction(slider:)), for: .valueChanged)
        timeSlider.addTarget(self, action: #selector(timeSliderTouchDragInsideAction), for: .touchDragInside)
        // controlView
        controlView.addSubview(playButton)
        controlView.addSubview(currentTimeLalbel)
        controlView.addSubview(totalTimeLalbel)
        controlView.addSubview(timeSlider)
        controlView.addSubview(fullScreenButton)
        addSubview(controlView)
    }
    /// 移除 AVPlayerItem 监听
    ///
    /// - Parameters:
    ///   - playerItem: AVPlayerItem
    private func removePlayerItemObserver(_ playerItem: AVPlayerItem?) {
        if let playItem = playerItem {
            player?.pause()
            playItem.removeObserver(self, forKeyPath: "status")
            playItem.removeObserver(self, forKeyPath: "loadedTimeRanges")
            playItem.removeObserver(self, forKeyPath: "playbackBufferEmpty")
            playItem.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp")
        }
    }
    /// 显示头和视频控制面板，如果处于播放状态，3秒后自动隐藏头和视频控制面板
    private func showHeaderAndControl() {
        isTapEnabled = false
        guard isHideHaderAndControl else {
            return
        }
        UIView.animate(withDuration: 0.5, animations: {
            if !self.isLandscape {
                self.bigPlayButton.isHidden = false
            }
            self.headerView.isHidden = false
            self.controlView.isHidden = false
        }) { _ in
            self.isHideHaderAndControl = false
            self.autoHideHeaderAndControl()
        }
        
    }
    /// 3秒自动隐藏头和视频控制面板
    private func autoHideHeaderAndControl() {
        if self.isPlaying {
            DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + Double(Int64(3 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)) {
                DispatchQueue.main.async {
                    self.isTapEnabled = true
                    if !self.isHideHaderAndControl && self.isPlaying {
                        self.hideHeaderAndControl()
                    }
                }
            }
        } else {
            isTapEnabled = true
        }
    }
    /// 隐藏头和视频控制面板
    private func hideHeaderAndControl() {
        guard !isHideHaderAndControl else {
            return
        }
        isTapEnabled = false
        UIView.animate(withDuration: 0.5, animations: {
            self.headerView.isHidden = true
            self.controlView.isHidden = true
            self.bigPlayButton.isHidden = true
        }) { _ in
            self.isTapEnabled = true
            self.isHideHaderAndControl = true
        }
    }
    /// 将秒转换为友好时间字符串
    private func convertTime(second: Float) -> String {
        let formatter = DateFormatter()
        if second / 3600 >= 1 {
            formatter.dateFormat = "HH:mm:ss"
        } else {
            formatter.dateFormat = "mm:ss"
        }
        let date = Date(timeIntervalSince1970: TimeInterval(second))
        return formatter.string(from: date)
    }
    /// 刷新播放按钮状态
    private func refreshPlayButton() {
        if isPlaying {
            playButton.setImage(pauseButtonImage, for: .normal)
            bigPlayButton.setImage(bigPauseButtonImage, for: .normal)
        } else {
            playButton.setImage(playButtonImage, for: .normal)
            bigPlayButton.setImage(bigPlayButtonImage, for: .normal)
        }
    }
    /// 显示加载
    private func showLoading() {
        activityView.startAnimating()
        activityView.isHidden = false
    }
    /// 隐藏加载
    private func hideLoading() {
        activityView.stopAnimating()
        activityView.isHidden = true
    }
}
