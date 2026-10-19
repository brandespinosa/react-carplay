import * as React from 'react';
import Tabs from '@mui/material/Tabs';
import Tab from '@mui/material/Tab';
import PhoneIcon from '@mui/icons-material/Phone';
import SettingsIcon from '@mui/icons-material/Settings';
import InfoIcon from '@mui/icons-material/Info';
import CameraIcon from '@mui/icons-material/Camera';
import { Link, useLocation } from "react-router-dom";
import ExitToApp from '@mui/icons-material/ExitToApp';
import { useStatusStore } from "../store/store";
import LoadingCar from "./LoadingCar";

export default function Nav({ receivingVideo, settings }) {
  const [value, setValue] = React.useState(0);
  const [isPlugged] = useStatusStore(state => [state.isPlugged])
  const { pathname } = useLocation()
  const handleChange = (_: React.SyntheticEvent, newValue: number) => {
    setValue(newValue);
  };

  const quit = () => {
    window.api.quit()
  }

  // Keep the screen black until the phone connects; a tap shows the menu for 10s
  const [showMenu, setShowMenu] = React.useState(false)
  const menuTimer = React.useRef<ReturnType<typeof setTimeout>>()
  const revealMenu = () => {
    clearTimeout(menuTimer.current)
    setShowMenu(true)
    menuTimer.current = setTimeout(() => setShowMenu(false), 10000)
  }
  React.useEffect(() => () => clearTimeout(menuTimer.current), [])

  return (
    <>
    {pathname === '/' && !isPlugged && !showMenu && (
      <div onClick={revealMenu} style={{ position: 'fixed', inset: 0, background: '#000', zIndex: 1200 }}>
        <LoadingCar />
      </div>
    )}
    <Tabs value={value} onChange={handleChange} aria-label="icon label tabs example" centered sx={pathname === '/' && isPlugged ? {minHeight: '0px', height: '0px'} : {}}>
      <Tab icon={<PhoneIcon />} to={'/'} component={Link}/>
      <Tab icon={<SettingsIcon />} to={'/settings'}  component={Link}/>
      <Tab icon={<InfoIcon />} to={'/info'} component={Link}/>
      {settings?.camera !== '' ? <Tab icon={<CameraIcon />} to={'/camera'} component={Link}/> : null}
      <Tab icon={<ExitToApp />} onClick={() => quit()} />
    </Tabs>
    </>
  );
}
