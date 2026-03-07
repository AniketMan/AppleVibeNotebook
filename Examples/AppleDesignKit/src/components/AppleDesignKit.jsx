// Example React Project: Apple Design Resources
// This demonstrates components from Figma's Apple iOS UI Kit
// converted to SwiftUI using the Figma Fast Path (1:1 mapping)

import React, { useState } from 'react';
import './AppleDesignKit.css';

// Navigation Bar - Apple iOS Style
export function NavigationBar({ title, leftAction, rightAction }) {
    return (
        <nav className="navigation-bar">
            <div className="nav-left">
                {leftAction && (
                    <button className="nav-button back-button" onClick={leftAction.onPress}>
                        <span className="sf-symbol">chevron.left</span>
                        <span>{leftAction.label}</span>
                    </button>
                )}
            </div>
            <h1 className="nav-title">{title}</h1>
            <div className="nav-right">
                {rightAction && (
                    <button className="nav-button" onClick={rightAction.onPress}>
                        {rightAction.label}
                    </button>
                )}
            </div>
        </nav>
    );
}

// Tab Bar - Apple iOS Style
export function TabBar({ tabs, selectedIndex, onSelect }) {
    return (
        <div className="tab-bar">
            {tabs.map((tab, index) => (
                <button
                    key={tab.id}
                    className={`tab-item ${index === selectedIndex ? 'selected' : ''}`}
                    onClick={() => onSelect(index)}
                >
                    <span className="sf-symbol">{tab.icon}</span>
                    <span className="tab-label">{tab.label}</span>
                </button>
            ))}
        </div>
    );
}

// List Cell - Apple iOS Style
export function ListCell({
    title,
    subtitle,
    leadingIcon,
    trailingContent,
    onPress,
    destructive = false
}) {
    return (
        <div
            className={`list-cell ${destructive ? 'destructive' : ''}`}
            onClick={onPress}
            role="button"
        >
            {leadingIcon && (
                <div className="cell-leading">
                    <span className="sf-symbol">{leadingIcon}</span>
                </div>
            )}
            <div className="cell-content">
                <span className="cell-title">{title}</span>
                {subtitle && <span className="cell-subtitle">{subtitle}</span>}
            </div>
            {trailingContent && (
                <div className="cell-trailing">
                    {trailingContent}
                </div>
            )}
            <span className="sf-symbol disclosure">chevron.right</span>
        </div>
    );
}

// Toggle (Switch) - Apple iOS Style
export function Toggle({ isOn, onChange, label }) {
    return (
        <label className="toggle-container">
            <span className="toggle-label">{label}</span>
            <div className={`toggle ${isOn ? 'on' : 'off'}`} onClick={() => onChange(!isOn)}>
                <div className="toggle-thumb" />
            </div>
        </label>
    );
}

// Segmented Control - Apple iOS Style
export function SegmentedControl({ segments, selectedIndex, onChange }) {
    return (
        <div className="segmented-control">
            {segments.map((segment, index) => (
                <button
                    key={index}
                    className={`segment ${index === selectedIndex ? 'selected' : ''}`}
                    onClick={() => onChange(index)}
                >
                    {segment}
                </button>
            ))}
        </div>
    );
}

// Button - Apple iOS Style
export function AppleButton({
    title,
    onPress,
    style = 'filled', // filled, tinted, gray, plain
    size = 'regular',  // small, regular, large
    disabled = false
}) {
    return (
        <button
            className={`apple-button ${style} ${size}`}
            onClick={onPress}
            disabled={disabled}
        >
            {title}
        </button>
    );
}

// Text Field - Apple iOS Style
export function TextField({
    placeholder,
    value,
    onChange,
    secure = false,
    clearButton = true
}) {
    return (
        <div className="text-field-container">
            <input
                type={secure ? 'password' : 'text'}
                className="text-field"
                placeholder={placeholder}
                value={value}
                onChange={(e) => onChange(e.target.value)}
            />
            {clearButton && value && (
                <button className="clear-button" onClick={() => onChange('')}>
                    <span className="sf-symbol">xmark.circle.fill</span>
                </button>
            )}
        </div>
    );
}

// Search Bar - Apple iOS Style
export function SearchBar({ placeholder = "Search", value, onChange, onCancel }) {
    const [isFocused, setIsFocused] = useState(false);

    return (
        <div className="search-bar-container">
            <div className={`search-bar ${isFocused ? 'focused' : ''}`}>
                <span className="sf-symbol search-icon">magnifyingglass</span>
                <input
                    type="text"
                    placeholder={placeholder}
                    value={value}
                    onChange={(e) => onChange(e.target.value)}
                    onFocus={() => setIsFocused(true)}
                    onBlur={() => setIsFocused(false)}
                />
                {value && (
                    <button className="clear-button" onClick={() => onChange('')}>
                        <span className="sf-symbol">xmark.circle.fill</span>
                    </button>
                )}
            </div>
            {isFocused && (
                <button className="cancel-button" onClick={onCancel}>
                    Cancel
                </button>
            )}
        </div>
    );
}

// Action Sheet Item
export function ActionSheetItem({ title, icon, onPress, destructive = false }) {
    return (
        <button
            className={`action-sheet-item ${destructive ? 'destructive' : ''}`}
            onClick={onPress}
        >
            {icon && <span className="sf-symbol">{icon}</span>}
            <span>{title}</span>
        </button>
    );
}

// Card - Apple iOS Style (Grouped List Background)
export function Card({ children, header, footer }) {
    return (
        <div className="card">
            {header && <div className="card-header">{header}</div>}
            <div className="card-content">{children}</div>
            {footer && <div className="card-footer">{footer}</div>}
        </div>
    );
}

// Progress View - Apple iOS Style
export function ProgressView({ value, total = 1.0, tint = 'blue' }) {
    const percentage = (value / total) * 100;

    return (
        <div className="progress-view">
            <div
                className={`progress-fill ${tint}`}
                style={{ width: `${percentage}%` }}
            />
        </div>
    );
}

// Activity Indicator - Apple iOS Style
export function ActivityIndicator({ size = 'medium' }) {
    return (
        <div className={`activity-indicator ${size}`}>
            <div className="spinner" />
        </div>
    );
}

// Main Settings Screen Example
export default function SettingsScreen() {
    const [notificationsEnabled, setNotificationsEnabled] = useState(true);
    const [darkModeEnabled, setDarkModeEnabled] = useState(false);
    const [selectedTab, setSelectedTab] = useState(0);

    const tabs = [
        { id: 'settings', icon: 'gear', label: 'Settings' },
        { id: 'profile', icon: 'person.circle', label: 'Profile' },
        { id: 'search', icon: 'magnifyingglass', label: 'Search' },
    ];

    return (
        <div className="screen">
            <NavigationBar
                title="Settings"
                rightAction={{ label: 'Done', onPress: () => {} }}
            />

            <div className="scroll-view">
                <Card header="GENERAL">
                    <ListCell
                        title="Notifications"
                        leadingIcon="bell.fill"
                        trailingContent={
                            <Toggle
                                isOn={notificationsEnabled}
                                onChange={setNotificationsEnabled}
                            />
                        }
                    />
                    <ListCell
                        title="Dark Mode"
                        leadingIcon="moon.fill"
                        trailingContent={
                            <Toggle
                                isOn={darkModeEnabled}
                                onChange={setDarkModeEnabled}
                            />
                        }
                    />
                    <ListCell
                        title="Privacy"
                        subtitle="Manage your data"
                        leadingIcon="lock.fill"
                        onPress={() => {}}
                    />
                </Card>

                <Card header="ACCOUNT">
                    <ListCell
                        title="Sign Out"
                        leadingIcon="rectangle.portrait.and.arrow.right"
                        destructive
                        onPress={() => {}}
                    />
                </Card>
            </div>

            <TabBar
                tabs={tabs}
                selectedIndex={selectedTab}
                onSelect={setSelectedTab}
            />
        </div>
    );
}
